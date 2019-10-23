
Agent/TCP/FullTcp set lddctcp_ 1
Agent/TCP/FullTcp set end_time 0
Agent/TCP/FullTcp set start_time 0
Agent/TCP/FullTcp set flow_max_cwnd_ 1
set W 15 
Agent/TCP/FullTcp set sfmw_threshold_ $W 

Agent/TCP set tcpagent_id 100000 

# how many levels of priority is used. 0----max_priority . 
Agent/TCP/FullTcp set max_priority 1 
Queue/WRPS set queue_num_ 1 
Queue/WRPS set marking_thresh_ 65
Queue/WRPS set q_weight_0_ 50
Queue/WRPS set q_weight_1_ 1

# the number of node
set N 3
# the number of the short flows in each groups. 
set M 800 
puts "ldctcp cwnd_thresholf_: $W M: $M "
Agent/TCP/FullTcp set flow_id 10000
Agent/TCP/FullTcp set max_short_flow_id [expr $N*$M] 

set B 250
set K 65
set RTT 0.0001

set simulationTime 1.0000000

set startMeasurementTime 1
set stopMeasurementTime 2

set sourceAlg DC-TCP-Sack
#set sourceAlg DC-TCP-Newreno
set switchAlg WRPS 

set inputLineRate 11Gb
set lineRate 10Gb
       set C 10

set DCTCP_g_ 0.0625
set ackRatio 1 
set packetSize 1460


set ns [new Simulator]
set traceall [open traceall.tr w]
#$ns trace-all $traceall

Agent/TCP set ecn_ 1
Agent/TCP set old_ecn_ 1
Agent/TCP set packetSize_ $packetSize
Agent/TCP/FullTcp set segsize_ $packetSize
Agent/TCP set window_ 1256
Agent/TCP set slow_start_restart_ false
Agent/TCP set tcpTick_ 0.01
#Agent/TCP set minrto_ 0.2 ; # minRTO = 200ms
Agent/TCP set minrto_ 0.01 ; # whx minRTO = 10ms
Agent/TCP set windowOption_ 0


if {[string compare $sourceAlg "DC-TCP-Sack"] == 0} {
    Agent/TCP set dctcp_ true
    Agent/TCP set dctcp_g_ $DCTCP_g_;
}

Agent/TCP/FullTcp set segsperack_ $ackRatio; 
Agent/TCP/FullTcp set spa_thresh_ 3000;
#Agent/TCP/FullTcp set interval_ 0.04 ; #delayed ACK interval = 40ms
Agent/TCP/FullTcp set interval_ 0.001 ; # delayed ACK interval = 40ms

Queue/RED set bytes_ false
Queue/RED set queue_in_bytes_ true
Queue/RED set mean_pktsize_ $packetSize
Queue/RED set setbit_ true
Queue/RED set gentle_ false
Queue/RED set q_weight_ 1.0
Queue/RED set mark_p_ 1.0
Queue/RED set thresh_ [expr $K]
Queue/RED set maxthresh_ [expr $K]
			 
DelayLink set avoidReordering_ true

proc finish {} {
        global ns  mytracefile utilization longflowthr queue traceall
        $ns flush-trace
        close $mytracefile
        close $utilization
	close $longflowthr
	close $queue
        close $traceall
        
	exit 0
}

proc cmptimeTrace {file} {
    global ns N M tcp    
    
    for {set i 0} {$i < $N*$M} {incr i} {
	    puts -nonewline $file "[$tcp($i) set fid_] [$tcp($i) set start_time] [$tcp($i) set end_time] "
	    puts $file "[expr [$tcp($i) set end_time]-[$tcp($i) set start_time]]"
#	  set start($i) [$tcp($i) set start_time]
#	  set end($i) [$tcp($i) set end_time]
	}
}       

proc long_flow_cwnd_trace {file} {
    global ns N M traceSamplingInterval tcp statistic_by_group  
    set now [$ns now]
    puts -nonewline $file "$now " 
    for {set i [expr $N*$M]} {$i < $N*$M+2} {incr i} {
	  set cwnd($i) [$tcp($i) set cwnd_]
	  puts -nonewline $file " $cwnd([expr $i]) "
    }
    puts $file ""
    $ns  at  [expr  $now + $traceSamplingInterval]  "long_flow_cwnd_trace $file"
}         
           
set statistic_by_group  0
proc short_flow_cwnd_trace {file} {
    global ns N M traceSamplingInterval tcp statistic_by_group  
    
    for {set i 0} {$i < $N*$M} {incr i} {
	  set cwnd($i) [$tcp($i) set flow_max_cwnd_]
	}
    if {$statistic_by_group} {  
          puts "group"	    
          for {set i 0} {$i < $M} {incr i} { 
                   puts -nonewline $file "$i " 
                   for {set j 0} {$j < $N} {incr j} {
                             puts -nonewline $file " $cwnd([expr $j*$M+$i]) " 
                   }
                   puts $file ""     
          } 
     } else {
                for {set i 0} {$i < $N*$M} {incr i} {
	              puts -nonewline $file "$i "
                      puts  $file " $cwnd([expr $i]) "       
                 }
                 #puts $file ""                
             }           
}

set Bcnt 0
set Dcnt 0
# calculate the utilization of the bottleneck link.
proc utilization {file} {
    global ns throughputSamplingInterval qfile  Bcnt Dcnt C
    
    set now [$ns now]
    
    $qfile instvar bdepartures_  pdepartures_ parrivals_ barrivals_ pdrops_ pkts_
    
    
    puts $file "$now [expr (($bdepartures_-$Bcnt)*8)/($C*1000.0*1000*1000*$throughputSamplingInterval)] $pkts_ [expr $pdrops_-$Dcnt]"
    set Bcnt $bdepartures_
    set Dcnt $pdrops_
    
    $ns at [expr $now+$throughputSamplingInterval] "utilization $file"
}


proc record_queue_drops {} {
        global ns queue qfile traceSamplingInterval
        $qfile instvar bdepartures_  pdepartures_ parrivals_ barrivals_ pdrops_ pkts_
        set    now   [$ns  now]
        puts $queue  "$now    [$qfile  set  size_] $pkts_ $pdrops_ "
        $ns  at  [expr  $now + $traceSamplingInterval]  "record_queue_drops"
}


set cmptimetracefile [open trace_cmptime.tr w]
set mytracefile [open trace_sfcwnd.tr w]
set utilization [open trace_utilization.tr w]
set longflowthr [open trace_longflowthr.tr w]
set longflowcwnd [open trace_longflowcwnd.tr w]

set traceSamplingInterval 0.0005
set throughputSamplingInterval 0.0005

$ns at 0.99999 "cmptimeTrace $cmptimetracefile"
$ns at 0.99999 "short_flow_cwnd_trace $mytracefile"
$ns at $throughputSamplingInterval "utilization $utilization"
$ns at $throughputSamplingInterval "long_flow_cwnd_trace $longflowcwnd"
$ns at 0.0 "record_queue_drops"

for {set i 0} {$i < $N} {incr i} {
    set n($i) [$ns node]
    set n([expr $i+$N]) [$ns node]
}
set nqueue [$ns node]
set nclient [$ns node]

for {set i 0} {$i < $N} {incr i} {   
       $ns duplex-link $n($i) $nqueue $inputLineRate [expr $RTT/6] DropTail
       # the qlimit_=50 in ns-default.tcl. the value is too small to drop packet in servere load. So, setting qlimit_=1000.
       $ns queue-limit $n($i) $nqueue 200
       $ns duplex-link $n([expr $i+$N]) $nclient $inputLineRate [expr $RTT/6] DropTail        
      # $ns queue-limit $n([expr $i+$N]) $nclient 1000
}
$ns simplex-link $nqueue $nclient $lineRate [expr $RTT/6] $switchAlg
$ns simplex-link $nclient $nqueue $lineRate [expr $RTT/6] DropTail
$ns queue-limit $nqueue $nclient $B
set queue [open trace_queue.tr w]
#monitor-queue can't automatically output the result into the trace file. Porcedure record{} must be invoked to output the result.
set qfile [$ns monitor-queue $nqueue $nclient $queue $traceSamplingInterval]

for {set j 0} {$j < $N} {incr j} { 
     for {set i 0} {$i < [expr $M]} {incr i} {
        
         if {[string compare $sourceAlg "Newreno"] == 0 || [string compare $sourceAlg "DC-TCP-Newreno"] == 0} {
	        set tcp([expr $j*$M+$i]) [new Agent/TCP/Newreno]
	        set sink([expr $j*$M+$i]) [new Agent/TCPSink]
         }
         if {[string compare $sourceAlg "Sack"] == 0 || [string compare $sourceAlg "DC-TCP-Sack"] == 0} { 
                 set tcp([expr $j*$M+$i]) [new Agent/TCP/FullTcp/Sack]
	         set sink([expr $j*$M+$i]) [new Agent/TCP/FullTcp/Sack]
	         $sink([expr $j*$M+$i]) listen

                 $tcp([expr $M*$j+$i]) set tcpagent_id [expr $M*$j+$i]
                 $sink([expr $M*$j+$i]) set tcpagent_id [expr 2*($M*$j+$i)]
         }

         $ns attach-agent $n($j) $tcp([expr $j*$M+$i])
         $ns attach-agent $n([expr $j+$N]) $sink([expr $j*$M+$i])
    
         $tcp([expr $j*$M+$i]) set fid_ [expr $j*$M+$i]
         $tcp([expr $j*$M+$i]) set flow_id [expr $j*$M+$i]
         $sink([expr $j*$M+$i]) set flow_id [expr 2*($j*$M+$i)]
         
         
         $ns connect $tcp([expr $j*$M+$i]) $sink([expr $j*$M+$i])   
                
    }
}        


for {set i 0} {$i < $M*$N} {incr i} {
    set ftp($i) [new Application/FTP]
    $ftp($i) attach-agent $tcp($i)    
}



set rng [new RNG]
$rng seed 1        

for {set i 0} {$i < $M*$N} {incr i} {

#********************************************************************************************
            set r [new RandomVariable/Uniform]
            $r use-rng $rng
            $r set min_ 0.1
            $r set max_ [expr $simulationTime*0.9]       

set starttime [expr [$r value] ]
#puts "$starttime"
if { $i < [expr $M] } {
            set s [new RandomVariable/Uniform]
          #  $s use-rng $rng
            $s set min_ 2 
            $s set max_ 14
	    set flowsize [expr int([expr [$s value]+0.5])]
      $ns at $starttime "$ftp($i) produce $flowsize"
    #  puts "$i $starttime $flowsize"
#    $ns at $starttime "$ftp($i) send 1000"
} elseif { $i < [expr $M*2] } {
            set s [new RandomVariable/Uniform]
            $s use-rng $rng
            $s set min_ 68 
            $s set max_ 204
	    set flowsize [expr int([expr [$s value]+0.5])]
      $ns at $starttime "$ftp($i) produce $flowsize"
      puts "$i $starttime $flowsize"
#    $ns at $starttime "$ftp($i) send 20000"
   
} else {
            set s [new RandomVariable/Uniform]
            $s use-rng $rng
            $s set min_  409
            $s set max_ 546
	    set flowsize [expr int([expr [$s value]+0.5])]
    $ns at $starttime "$ftp($i) produce $flowsize"
 #     puts "$i $starttime $flowsize"
#    $ns at $starttime "$ftp($i) send 800000"
}
}

# the two long background flows.
set Q 2 
set bs [$ns node]
set br [$ns node]
$ns duplex-link $bs $nqueue $inputLineRate [expr $RTT/6] DropTail
$ns duplex-link $br $nclient $inputLineRate [expr $RTT/6] DropTail      

for {set i 0} {$i < $Q} {incr i} {
      
         if {[string compare $sourceAlg "Newreno"] == 0 || [string compare $sourceAlg "DC-TCP-Newreno"] == 0} {
	        set tcp([expr $M*$N+$i]) [new Agent/TCP/Newreno]
	        set sink([expr $M*$N+$i]) [new Agent/TCPSink]
         }
         if {[string compare $sourceAlg "Sack"] == 0 || [string compare $sourceAlg "DC-TCP-Sack"] == 0} { 
                 set tcp([expr $M*$N+$i]) [new Agent/TCP/FullTcp/Sack]
	        set sink([expr $M*$N+$i]) [new Agent/TCP/FullTcp/Sack]
	        $sink([expr $M*$N+$i]) listen


 }

         $ns attach-agent $bs $tcp([expr $M*$N+$i])
         $ns attach-agent $br $sink([expr $M*$N+$i])
    
         $tcp([expr $M*$N+$i]) set fid_ [expr $M*$N+$i]         
         
         $ns connect $tcp([expr $M*$N+$i]) $sink([expr $M*$N+$i])   

         set ftp([expr $M*$N+$i]) [new Application/FTP]
         $ftp([expr $M*$N+$i]) attach-agent $tcp([expr $M*$N+$i])   
         
         
#        $ns at [expr $i*0.1] "$ftp([expr $M*$N+$i]) start"
         $ns at $simulationTime  "$ftp([expr $M*$N+$i]) stop"                 
   

}        
       $ns at 0.03 "$ftp([expr $M*$N+1]) start"       
        $ns at 0.0 "$ftp([expr $M*$N]) start"    

set flowmon [$ns makeflowmon Fid]
#$flowmon attach $longflowthr
set MainLink [$ns link $nqueue $nclient]

$ns attach-fmon $MainLink $flowmon

set fcl [$flowmon classifier]
set flowClassifyTime 0.0001
$ns at $flowClassifyTime "classifyflow0"
$ns at 0.0301 "classifyflow1"

proc classifyflow0 {} {
    global ns N M fcl longflow0 longflow1
#    puts "NOW CLASSIFYING FLOWS 0"
    set longflow0 [$fcl lookup autp 0 0  [expr $N*$M]]
  #  set flow([expr $N*$M]) [$fcl lookup autp [expr $N*2] [expr $N*2+1] [expr $N*$M]]
}
proc classifyflow1 {} {
    global ns N M fcl longflow1
#    puts "NOW CLASSIFYING FLOWS 1"
    set longflow1 [$fcl lookup autp 0 0 [expr $N*$M+1]]
}


# calculate long flow throughput
proc longflowthr {file} {
    global ns throughputSamplingInterval qfile longflow0 longflow1 N M flowClassifyTime
    
    set now [$ns now]
    if {$now <= $flowClassifyTime} {            
            puts -nonewline $file "$now "
	    puts -nonewline $file " 0"
	    set barrivals_ 0
            puts $file " 0"
    } elseif {$now <= 0.0301} {
            puts -nonewline $file "$now "
	    $longflow0 instvar barrivals_
	    puts -nonewline $file " [expr $barrivals_*8/$throughputSamplingInterval/1000000]"
	    set barrivals_ 0
            puts $file " 0"
    } else {
            puts -nonewline $file "$now "
	    $longflow0 instvar barrivals_
	    puts -nonewline $file " [expr $barrivals_*8/$throughputSamplingInterval/1000000]"
	    set barrivals_ 0
	$longflow1 instvar barrivals_
	puts $file " [expr $barrivals_*8/$throughputSamplingInterval/1000000]"
	set barrivals_ 0
    }

    $ns at [expr $now+$throughputSamplingInterval] "longflowthr $file"
}

$ns at $throughputSamplingInterval "longflowthr $longflowthr"

                      
$ns at $simulationTime "finish"

$ns run

