#!/usr/bin/tclsh
#
# Run this script using TCLSH to do a speed comparison
#
# Originally tool/speedtest.tcl from https://sqlite.org
#
# Modifications copyright 2019 The LumoSQL Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations under
# the License.
#
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2019 The LumoSQL Authors
#
# /tool/speedtest.tcl [HTML_OUTPUT]

if {[llength $argv]>0} {
  set ofd [open [lindex $argv 0] w]
} else {
  set ofd [open "/dev/null" w]
}

set cnt 1
proc runtest {title} {
  global cnt
  global ofd
  set sqlfile test$cnt.sql
  puts $ofd "<h2>Test $cnt: $title</h2>"
  set origcnt $cnt
  incr cnt
  set fd [open $sqlfile r]
  set sql [string trim [read $fd [file size $sqlfile]]]
  close $fd
  set sx [split $sql \n]
  set n [llength $sx]
  if {$n>8} {
    set sql {}
    for {set i 0} {$i<3} {incr i} {append sql [lindex $sx $i]<br>\n}
    append sql  "<i>... [expr {$n-6}] lines omitted</i><br>\n"
    for {set i [expr {$n-3}]} {$i<$n} {incr i} {
      append sql [lindex $sx $i]<br>\n
    }
  } else {
    regsub -all \n [string trim $sql] <br> sql
  }
  puts $ofd "<blockquote>"
  puts $ofd "$sql"
  puts $ofd "</blockquote><table border=0 cellpadding=0 cellspacing=0>"
  set format {<tr><td>%s</td><td align="right">&nbsp;&nbsp;&nbsp;%.3f</td></tr>}
  set delay 1000
  exec sync; after $delay;
  set t [time "exec ./sqlite3 s2k.db <$sqlfile" 1]
  set t [expr {[lindex $t 0]/1000000.0}]
  set v [exec ./sqlite3 --version]
  puts $ofd [format $format $v $t]
  puts $ofd "</table>"
  flush $ofd
  puts [format "%8.3f %3d %s" $t $origcnt $title]
  flush stdout
}

# Initialize the environment
#
expr srand(1)
catch {exec /bin/sh -c {rm -f s*.db}}
set fd [open clear.sql w]
puts $fd {
  drop table t1;
  drop table t2;
}
close $fd
catch {exec psql drh <clear.sql}
catch {exec mysql drh <clear.sql}
set fd [open 2kinit.sql w]
puts $fd {
  PRAGMA default_synchronous=on;
}
# Including the pragma below in the file above causes unknown operation error
# PRAGMA default_cache_size=2000;
close $fd
exec ./sqlite3 s2k.db <2kinit.sql
set ones {zero one two three four five six seven eight nine
          ten eleven twelve thirteen fourteen fifteen sixteen seventeen
          eighteen nineteen}
set tens {{} ten twenty thirty forty fifty sixty seventy eighty ninety}
proc number_name {n} {
  if {$n>=1000} {
    set txt "[number_name [expr {$n/1000}]] thousand"
    set n [expr {$n%1000}]
  } else {
    set txt {}
  }
  if {$n>=100} {
    append txt " [lindex $::ones [expr {$n/100}]] hundred"
    set n [expr {$n%100}]
  }
  if {$n>=20} {
    append txt " [lindex $::tens [expr {$n/10}]]"
    set n [expr {$n%10}]
  }
  if {$n>0} {
    append txt " [lindex $::ones $n]"
  }
  set txt [string trim $txt]
  if {$txt==""} {set txt zero}
  return $txt
}



set fd [open test$cnt.sql w]
puts $fd "CREATE TABLE t1(a INTEGER, b INTEGER, c VARCHAR(100));"
for {set i 1} {$i<=1000} {incr i} {
  set r [expr {int(rand()*100000)}]
  puts $fd "INSERT INTO t1 VALUES($i,$r,'[number_name $r]');"
}
close $fd
runtest {1000 INSERTs}



set fd [open test$cnt.sql w]
puts $fd "BEGIN;"
puts $fd "CREATE TABLE t2(a INTEGER, b INTEGER, c VARCHAR(100));"
for {set i 1} {$i<=25000} {incr i} {
  set r [expr {int(rand()*500000)}]
  puts $fd "INSERT INTO t2 VALUES($i,$r,'[number_name $r]');"
}
puts $fd "COMMIT;"
close $fd
runtest {25000 INSERTs in a transaction}



set fd [open test$cnt.sql w]
for {set i 0} {$i<100} {incr i} {
  set lwr [expr {$i*100}]
  set upr [expr {($i+10)*100}]
  puts $fd "SELECT count(*), avg(b) FROM t2 WHERE b>=$lwr AND b<$upr;"
}
close $fd
runtest {100 SELECTs without an index}



set fd [open test$cnt.sql w]
for {set i 1} {$i<=100} {incr i} {
  puts $fd "SELECT count(*), avg(b) FROM t2 WHERE c LIKE '%[number_name $i]%';"
}
close $fd
runtest {100 SELECTs on a string comparison}


# Duplicate values and an index cause an error
# Error: database disk image is malformed
# set fd [open test$cnt.sql w]
# puts $fd {CREATE INDEX i2a ON t2(a);}
# puts $fd {CREATE INDEX i2b ON t2(b);}
# close $fd
# runtest {Creating an index}



set fd [open test$cnt.sql w]
for {set i 0} {$i<5000} {incr i} {
  set lwr [expr {$i*100}]
  set upr [expr {($i+1)*100}]
  puts $fd "SELECT count(*), avg(b) FROM t2 WHERE b>=$lwr AND b<$upr;"
}
close $fd
runtest {5000 SELECTs}



set fd [open test$cnt.sql w]
puts $fd "BEGIN;"
for {set i 0} {$i<1000} {incr i} {
  set lwr [expr {$i*10}]
  set upr [expr {($i+1)*10}]
  puts $fd "UPDATE t1 SET b=b*2 WHERE a>=$lwr AND a<$upr;"
}
puts $fd "COMMIT;"
close $fd
runtest {1000 UPDATEs without an index}



set fd [open test$cnt.sql w]
puts $fd "BEGIN;"
for {set i 1} {$i<=25000} {incr i} {
  set r [expr {int(rand()*500000)}]
  puts $fd "UPDATE t2 SET b=$r WHERE a=$i;"
}
puts $fd "COMMIT;"
close $fd
runtest {25000 UPDATEs with an index}


set fd [open test$cnt.sql w]
puts $fd "BEGIN;"
for {set i 1} {$i<=25000} {incr i} {
  set r [expr {int(rand()*500000)}]
  puts $fd "UPDATE t2 SET c='[number_name $r]' WHERE a=$i;"
}
puts $fd "COMMIT;"
close $fd
runtest {25000 text UPDATEs with an index}



set fd [open test$cnt.sql w]
puts $fd "BEGIN;"
puts $fd "INSERT INTO t1 SELECT * FROM t2;"
puts $fd "INSERT INTO t2 SELECT * FROM t1;"
puts $fd "COMMIT;"
close $fd
runtest {INSERTs from a SELECT}



set fd [open test$cnt.sql w]
puts $fd {DELETE FROM t2 WHERE c LIKE '%fifty%';}
close $fd
runtest {DELETE without an index}



set fd [open test$cnt.sql w]
puts $fd {DELETE FROM t2 WHERE a>10 AND a<20000;}
close $fd
runtest {DELETE with an index}



set fd [open test$cnt.sql w]
puts $fd {INSERT INTO t2 SELECT * FROM t1;}
close $fd
runtest {A big INSERT after a big DELETE}



set fd [open test$cnt.sql w]
puts $fd {BEGIN;}
puts $fd {DELETE FROM t1;}
for {set i 1} {$i<=3000} {incr i} {
  set r [expr {int(rand()*100000)}]
  puts $fd "INSERT INTO t1 VALUES($i,$r,'[number_name $r]');"
}
puts $fd {COMMIT;}
close $fd
runtest {A big DELETE followed by many small INSERTs}



set fd [open test$cnt.sql w]
puts $fd {DROP TABLE t1;}
puts $fd {DROP TABLE t2;}
close $fd
runtest {DROP TABLE}

close $ofd

