1. Your decision: which architecture and why
   
I went with Architecture B The lake is the truth because it avoids keeping a separate state file in sync with the actual data.

With a state file (Architecture A), there is always a gap between writing the files and updating the state. If the job crashes right in between, the next run doesn't know the data was already written and writes it again, creating duplicates. Architecture B solves this by making the lake itself the single source of truth. By writing everything to a STAGING folder first and then moving it into LAKE with a single publish(run) rename, the data either appears completely or not at all. There is no separate state to manage or fall out of sync, and readers never have to worry about deduplicating data on the fly like they would in Architecture C.

2. Explain your result

run_once() passes all five test scenarios in check_all, including the ones that simulate a crash halfway through a run.

Normal and empty runs: It checks lake_position() to see where the last run ended, reads only the new records, and skips writing if nothing new arrived (new.end == start).

Crash during writing: If the job stops while write_files(new, STAGING) is still running, the partial files stay isolated in STAGING. LAKE isn't touched, readers never see broken Parquet files, and the next run simply reads the same lake_position() and retries from the exact same spot.

Atomic publishing: Once publish(run) moves the finished folder into LAKE, the new records—and the new lake position—become visible at the exact same moment. That guarantees no record is missed and no record is written twice.

3. The output of check_all.
```  
situation                                 in lake  duplicates  missing  not loaded    run  check
-----------------------------------------------------------------------------------------------
1 first run                             2,000,000           0        0           0  18.2s  PASS
2 new records arrive, run again         2,100,000           0        0           0   5.0s  PASS
3 nothing new, run again                2,100,000           0        0           0   0.3s  PASS
4 run stops WHILE writing: right after  2,100,000           0        0     100,000         PASS
  ... then the next run                 2,200,000           0        0           0   5.8s  PASS
5 run stops AFTER writing: right after  2,200,000           0        0     100,000         PASS
  ... then the next run                 2,300,000           0        0           0   5.0s  PASS
-----------------------------------------------------------------------------------------------**

[('1 first run',
  {'topic': 2000000,
   'lake': 2000000,
   'dup': 0,
   'miss': 0,
   'lag': 0,
   'files': 4,
   'mb': 111.352439,
   'ok': True,
   'problems': []},
  18.161290645599365),
 ('2 new records arrive, run again',
  {'topic': 2100000,
   'lake': 2100000,
   'dup': 0,
   'miss': 0,
   'lag': 0,
   'files': 8,
   'mb': 112.429628,
   'ok': True,
   'problems': []},
  4.9903342723846436),
 ('3 nothing new, run again',
  {'topic': 2100000,
   'lake': 2100000,
   'dup': 0,
   'miss': 0,
   'lag': 0,
   'files': 8,
   'mb': 112.429628,
   'ok': True,
   'problems': []},
  0.2742431163787842),
 ('4 run stops WHILE writing: right after',
  {'topic': 2200000,
   'lake': 2100000,
   'dup': 0,
   'miss': 0,
   'lag': 100000,
   'files': 8,
   'mb': 112.429628,
   'ok': True,
   'problems': []},
  None),
 ('  ... then the next run',
  {'topic': 2200000,
   'lake': 2200000,
   'dup': 0,
   'miss': 0,
   'lag': 0,
   'files': 11,
   'mb': 113.53093,
   'ok': True,
   'problems': []},
  5.826475620269775),
 ('5 run stops AFTER writing: right after',
  {'topic': 2300000,
   'lake': 2200000,
   'dup': 0,
   'miss': 0,
   'lag': 100000,
   'files': 11,
   'mb': 113.53093,
   'ok': True,
   'problems': []},
  None),
 ('  ... then the next run',
  {'topic': 2300000,
   'lake': 2300000,
   'dup': 0,
   'miss': 0,
   'lag': 0,
   'files': 15,
   'mb': 114.583785,
   'ok': True,
   'problems': []},
  4.97712779045105)]
```
