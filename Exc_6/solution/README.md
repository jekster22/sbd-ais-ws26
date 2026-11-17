## Task 1

I went with log-based CDC (Debezium). The payment path isn't ours and it's certified, so anything that touches card_processor.py, like dual write or an outbox, wasn't really an option. Polling would work without code changes, but every agent would keep hitting the system of record with queries, and we already saw in Line Guardian that it misses rows that commit out of id order. With Debezium we just read the WAL, so the payment path stays the same, never waits on us, and we still get every commit in the right order. The catch is the replication slot. If the connector goes down over a weekend, Postgres keeps all the WAL it hasn't read yet, the disk slowly fills up, and at some point the payment path goes down with it. So I'd monitor the connector status and how much WAL the slot is holding back pg_replication_slots, alert well before the disk gets tight, and set max_slot_wal_keep_size as a last line of defence. If we owned the payment path, I'd probably pick an outbox instead, because then we decide what the event looks like instead of just mirroring the table.

## The runs

### Run 1 - Debezium defaults
Prediction: agents.py starts three velocity agents, so I expected them to split
the load and R4 to pass.

```
R3  frauds caught          0/5  (0%)   FAIL  (>= 90 %)
R4  no alerts; worst lag of the velocity agents 538.6 s   FAIL  (<= 5 s)
```

Why: I was wrong. The topic was created with only 1 partition, and in a consumer
group one partition goes to exactly one instance. vel-1 got [0], vel-2 and vel-3 got
[] and did nothing, and one instance alone can't keep up with 1,000 payments/s.
The lag kept growing almost 490k events behind, so the frauds were still waiting in
the backlog and no alert came out at all.

### Run 2 - 6 partitions
Prediction: now every agent gets two partitions, so R4 should pass. I wasn't sure
about R3, because the key was still the payment id.

```
R3  frauds caught          2/8  (25%)   FAIL  (>= 90 %)
R4  alert latency p50/p95  0.8 s / 1.0 s   PASS  (p95 <= 5 s after the commit)
```

Why: The agents got [0, 1], [2, 3], [4, 5] and kept up lag around 100 events
per partition, so R4 passed. But the key was still {"id": ...}, so the 12 test
payments of one stolen card were hashed across all six partitions and each agent only
saw part of the attack, usually less than the 8 it needs. The two catches were cards
where enough payments happened to land with the same agent.

### Run 3 - cardholder as the key
Prediction: the key becomes {"user_id": ...}, so all payments of a cardholder go
to the same partition and agent. R3 and R4 should both pass.

```
R3  frauds caught          8/8  (100%)   PASS  (>= 90 %)
R4  alert latency p50/p95  0.8 s / 1.1 s   PASS  (p95 <= 5 s after the commit)
```

Why: With message.key.columns = public.transactions:user_id one agent sees every
payment of a cardholder, in commit order, so the 60-second count reaches 8 and the
alert fires. The load is still spread over 6 partitions about 52k payments per
agent, so latency stayed around one second.

## 3. Closing answer

If nobody had checked, production would first have run on one partition: adding fraud
agents would have changed nothing, the lag would have grown all day and alerts would
have come minutes or hours late, long after the thief's next payment. If someone then
"fixed" that by just adding partitions, the velocity model would have quietly stopped
catching card testing 25% in our run. Neither case crashes or logs an error, so
everything looks healthy. The team could have noticed with consumer-lag and
commit-to-alert latency monitoring, by alerting on group members with no partitions,
by watching the alert rate drop compared to before, or by replaying labelled data
through the pipeline before going live.

## 4. Final connector
```
{
  "name": "fraud-connector",
  "config": {
    "connector.class": "io.debezium.connector.postgresql.PostgresConnector",
    "database.hostname": "postgres",
    "database.port": "5432",
    "database.user": "postgres",
    "database.password": "postgrespw",
    "database.dbname": "mydb",
    "topic.prefix": "fraud",
    "plugin.name": "pgoutput",
    "decimal.handling.mode": "double",
    "table.include.list": "public.transactions",
    "slot.name": "fraudslot",
    "topic.creation.default.partitions": "6",
    "topic.creation.default.replication.factor": "1",
    "message.key.columns": "public.transactions:user_id"
  }
}
```
