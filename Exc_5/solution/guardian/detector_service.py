"""The anomaly detector as a Kafka service. YOUR CODE (Part 2, Stage C2).

The plumbing is here, the decisions (marked TODO) are yours. Contract with
the maintenance team: every reading goes through model.score(); every
reading with score >= model.threshold becomes ONE anomaly event,
model.anomaly_event(reading, score), as JSON, published to the topic
`anomalies`.
I used Claude to help me with logs and code.

    python3 detector_service.py --name det-1
    python3 detector_service.py --name det-2          # one more instance
"""
import argparse
import json
import time

from confluent_kafka import Consumer, KafkaException, Producer

from model import BearingModel

ap = argparse.ArgumentParser()
ap.add_argument("--name", default="det-1", help="instance name (shows up in the scoreboard)")
ap.add_argument("--in-topic", default="readings", help="the topic the gateways write to")
ap.add_argument("--group", default="line-guardian-detector", help="the consumer group of this detector")
ap.add_argument("--out-topic", default="anomalies")
ap.add_argument("--bootstrap", default="localhost:9092")
args = ap.parse_args()

model = BearingModel(instance=args.name)
consumer = Consumer({
    "bootstrap.servers": args.bootstrap,
    "group.id": args.group,
    "client.id": args.name,
    "auto.offset.reset": "latest",              
    "enable.auto.commit": True,                
    "enable.auto.offset.store": False,          
    "partition.assignment.strategy": "cooperative-sticky",
    "session.timeout.ms": 10000,               
    "heartbeat.interval.ms": 3000,
})
producer = Producer({
    "bootstrap.servers": args.bootstrap,
    "client.id": f"{args.name}-anomalies",
    "partitioner": "murmur2_random",
    "enable.idempotence": True,                 
    "linger.ms": 0,                             
})

machine_partition = {}                        


def on_assign(c, partitions):
    print(f"[{args.name}] assigned partitions: {sorted(p.partition for p in partitions)}", flush=True)


def on_revoke(c, partitions):
    revoked = {p.partition for p in partitions}
    if not revoked:
        return
    try:
        c.commit(asynchronous=False)            
    except KafkaException:
        pass                                  
    gone = [m for m, p in machine_partition.items() if p in revoked]
    for m in gone:
        model.forget(m)
        del machine_partition[m]
    print(f"[{args.name}] revoked partitions:  {sorted(revoked)} (forgot {len(gone)} machines)", flush=True)


consumer.subscribe([args.in_topic], on_assign=on_assign, on_revoke=on_revoke, on_lost=on_revoke)
print(f"[{args.name}] {args.in_topic} -> {args.out_topic}, group {args.group} (Ctrl+C to stop)", flush=True)

readings = anomalies = 0
report_at = time.time() + 5
try:
    while True:
        msg = consumer.poll(1.0)
        if msg is None:
            continue
        if msg.error():
            print(f"[{args.name}] {msg.error()}")
            continue
        reading = json.loads(msg.value())
        machine_partition[reading["machine_id"]] = msg.partition()
        score = model.score(reading)
        readings += 1
        if score is not None and score >= model.threshold:
            anomalies += 1
            event = model.anomaly_event(reading, score)
            producer.produce(args.out_topic, key=reading["machine_id"], value=json.dumps(event))
        try:
            consumer.store_offsets(message=msg)
        except KafkaException:
            pass                                
        producer.poll(0)
        if time.time() >= report_at:
            lag = time.time() - reading["ts"]
            print(f"[{args.name}] {readings:>9,} readings  {anomalies:>6,} anomalies  "
                  f"missing {model.missing}  out-of-order {model.out_of_order}  "
                  f"machines {len(model.machines())}  delay {lag:.2f} s", flush=True)
            report_at += 5
except KeyboardInterrupt:
    pass
finally:
    producer.flush(10)
    consumer.close()                           
    print(f"[{args.name}] stopped after {readings:,} readings, {anomalies:,} anomalies", flush=True)
