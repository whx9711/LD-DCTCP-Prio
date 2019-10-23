# LD-DCTCP-Prio
LD-DCTCP-Prio adopts priority queue schedule at swithes, rather than weighted fair queue in LD-DCTCP

It is easy to implement LD-DCTCP-Prio.

Step 1:  replace the file with the same name wrps.cc  in LD-DCTCP

Step 2:  go to folder ns2.34, and run command:   make

Step 3:  run the simulation script:   ns lddctcp.tcl

Step 4: The completion time of short flows can be found at file trace_cmptime.tr.
