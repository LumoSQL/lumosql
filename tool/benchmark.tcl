#!/usr/bin/tclsh
#
# Run this script using TCLSH to benchmark one or more lumosql targets
#
# Originally tool/speedtest.tcl from https://sqlite.org
#
# Modifications copyright 2020 The LumoSQL Authors
#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2020 The LumoSQL Authors
#
# /tool/benchmark.tcl

package require Tclx 8.0

if {[llength $argv] < 5} {
  puts stderr "Usage: benchmark.tcl BUILD_DIR DATABASE TARGET_FOR_DB N_RUNS TARGETS...";
  exit 1
}
set build_dir [lindex $argv 0]
set result_db [lindex $argv 1]
set db_target [lindex $argv 2]
set n_runs [lindex $argv 3]
set sqlite3_result "$build_dir/$db_target/sqlite3/sqlite3"
set run_dir "$build_dir/.lumo.tests"

expr srand(1)

# if the database exists, check it has the correct tables;
# if it does not exist, create it
set run_schema {
    CREATE TABLE run_data (
	run_id VARCHAR(128),
	key VARCHAR(256),
	value TEXT
    );
    CREATE INDEX run_data_index ON run_data (run_id, key);
}
set test_schema {
    CREATE TABLE test_data (
	run_id VARCHAR(128),
	test_number INTEGER,
	key VARCHAR(256),
	value TEXT
    );
    CREATE INDEX test_data_index_1 ON test_data (run_id, test_number, key);
    CREATE INDEX test_data_index_2 ON test_data (run_id, key, test_number);
}

if {[file exists $result_db]} {
    # TODO get table schemas and check them
} else {
    puts "Creating database $result_db"
    flush stdout
    set sqlfd [open "| $sqlite3_result $result_db" w]
    puts $sqlfd $run_schema
    puts $sqlfd $test_schema
    close $sqlfd
}

# generate strings from numbers, used by some of the tests
set ones {zero one two three four five six seven eight nine
          ten eleven twelve thirteen fourteen fifteen sixteen seventeen
          eighteen nineteen}
set tens {{} ten twenty thirty forty fifty sixty seventy eighty ninety}
proc number_name {n} {
  set txt {}
  if {$n >= 1000000} {
    append txt " [number_name [expr {$n/1000000}]] million"
    set n [expr {$n%1000000}]
  }
  if {$n>=1000} {
    append txt " [number_name [expr {$n/1000}]] thousand"
    set n [expr {$n%1000}]
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

set cnt 0
set target_db ""
set run_id ""
set sql_file "$run_dir/test.sql"
set tests_ok 0
set tests_intr 0
set tests_fail 0

# run a single test
proc run_test {title} {
    global cnt
    global target_db
    global run_dir
    global run_id
    global sql_file
    global tests_ok
    global tests_intr
    global tests_fail
    global sqlite3_result
    global result_db

    incr cnt
    set delay 1000
    exec sync; after $delay;
    set status "?"
    set oct [times]
    set owt [clock microseconds]
    if {[catch {
	exec $target_db "$run_dir/bench.db" < $sql_file
    } res opt]} {
	set S [dict get $opt -errorcode]
	set E [lindex $S 0]
	if {$E eq "CHILDKILLED"} {
	    set status [lindex $S 2]
	    incr tests_intr
	} elseif {$E eq "CHILDSTATUS"} {
	    set status "ERR[lindex $S 2]"
	    incr tests_fail
	}
    } else {
	set status "OK"
	incr tests_ok
    }
    set nwt [clock microseconds]
    set nct [times]
    set wt [expr {($nwt - $owt) / 1000000.0}]
    set ut [expr {([lindex $nct 2] - [lindex $oct 2]) / 1000.0}]
    set st [expr {([lindex $nct 3] - [lindex $oct 3]) / 1000.0}]
    set sql_fd [open "| $sqlite3_result $result_db" w];
    puts $sql_fd "insert into test_data (run_id, test_number, key, value)
		  values ('$run_id', $cnt, 'test-name', '$title');"
    puts $sql_fd "insert into test_data (run_id, test_number, key, value)
		  values ('$run_id', $cnt, 'real-time', $wt);"
    puts $sql_fd "insert into test_data (run_id, test_number, key, value)
		  values ('$run_id', $cnt, 'user-cpu-time', $ut);"
    puts $sql_fd "insert into test_data (run_id, test_number, key, value)
		  values ('$run_id', $cnt, 'system-cpu-time', $st);"
    puts $sql_fd "insert into test_data (run_id, test_number, key, value)
		  values ('$run_id', $cnt, 'status', '$status');"
    close $sql_fd
    puts [format "%8s %8.3f %3d %s" $status $wt $cnt $title]
    flush stdout
}

# run a set of tests
proc run_tests {} {
    global sql_file
    global cnt
    global datasize

    set cnt 0
    set tests_ok 0
    set tests_intr 0
    set tests_fail 0

    #set d100 [expr {$datasize * 100}]
    set d100 100
    set d1000 [expr {$datasize * 1000}]
    #set d5000 [expr {$datasize * 5000}]
    set d5000 5000
    set d25000 [expr {$datasize * 25000}]

    set fd [open $sql_file w]
    puts $fd "CREATE TABLE t1(a INTEGER, b INTEGER, c VARCHAR(100));"
    for {set i 1} {$i<=$d1000} {incr i} {
      set r [expr {int(rand()*100000)}]
      puts $fd "INSERT INTO t1 VALUES($i,$r,'[number_name $r]');"
    }
    close $fd
    run_test "$d1000 INSERTs"

    set fd [open $sql_file w]
    puts $fd "BEGIN;"
    puts $fd "CREATE TABLE t2(a INTEGER, b INTEGER, c VARCHAR(100));"
    for {set i 1} {$i<=$d25000} {incr i} {
      set r [expr {int(rand()*500000)}]
      puts $fd "INSERT INTO t2 VALUES($i,$r,'[number_name $r]');"
    }
    puts $fd "COMMIT;"
    close $fd
    run_test "$d25000 INSERTs in a transaction"

    set fd [open $sql_file w]
    for {set i 0} {$i<$d100} {incr i} {
      set lwr [expr {$i*100}]
      set upr [expr {($i+10)*100}]
      puts $fd "SELECT count(*), avg(b) FROM t2 WHERE b>=$lwr AND b<$upr;"
    }
    close $fd
    run_test "$d100 SELECTs without an index"

    set fd [open $sql_file w]
    for {set i 1} {$i<=$d100} {incr i} {
      puts $fd "SELECT count(*), avg(b) FROM t2 WHERE c LIKE '%[number_name $i]%';"
    }
    close $fd
    run_test "$d100 SELECTs on a string comparison"

    # Duplicate values and an index cause an error
    # Error: database disk image is malformed
    # set fd [open $sql_file w]
    # puts $fd {CREATE INDEX i2a ON t2(a);}
    # puts $fd {CREATE INDEX i2b ON t2(b);}
    # close $fd
    # run_test {Creating an index}

    set fd [open $sql_file w]
    for {set i 0} {$i<$d5000} {incr i} {
      set lwr [expr {$i*100}]
      set upr [expr {($i+1)*100}]
      puts $fd "SELECT count(*), avg(b) FROM t2 WHERE b>=$lwr AND b<$upr;"
    }
    close $fd
    run_test "$d5000 SELECTs"

    set fd [open $sql_file w]
    puts $fd "BEGIN;"
    for {set i 0} {$i<$d1000} {incr i} {
      set lwr [expr {$i*10}]
      set upr [expr {($i+1)*10}]
      puts $fd "UPDATE t1 SET b=b*2 WHERE a>=$lwr AND a<$upr;"
    }
    puts $fd "COMMIT;"
    close $fd
    run_test "$d1000 UPDATEs without an index"

    set fd [open $sql_file w]
    puts $fd "BEGIN;"
    for {set i 1} {$i<=$d25000} {incr i} {
      set r [expr {int(rand()*500000)}]
      puts $fd "UPDATE t2 SET b=$r WHERE a=$i;"
    }
    puts $fd "COMMIT;"
    close $fd
    run_test "$d25000 UPDATEs with an index"

    set fd [open $sql_file w]
    puts $fd "BEGIN;"
    for {set i 1} {$i<=$d25000} {incr i} {
      set r [expr {int(rand()*500000)}]
      puts $fd "UPDATE t2 SET c='[number_name $r]' WHERE a=$i;"
    }
    puts $fd "COMMIT;"
    close $fd
    run_test "$d25000 text UPDATEs with an index"

    set fd [open $sql_file w]
    puts $fd "BEGIN;"
    puts $fd "INSERT INTO t1 SELECT * FROM t2;"
    puts $fd "INSERT INTO t2 SELECT * FROM t1;"
    puts $fd "COMMIT;"
    close $fd
    run_test {INSERTs from a SELECT}

    set fd [open $sql_file w]
    puts $fd {DELETE FROM t2 WHERE c LIKE '%fifty%';}
    close $fd
    run_test {DELETE without an index}

    set fd [open $sql_file w]
    puts $fd {DELETE FROM t2 WHERE a>10 AND a<20000;}
    close $fd
    run_test {DELETE with an index}

    set fd [open $sql_file w]
    puts $fd {INSERT INTO t2 SELECT * FROM t1;}
    close $fd
    run_test {A big INSERT after a big DELETE}

    set fd [open $sql_file w]
    puts $fd {BEGIN;}
    puts $fd {DELETE FROM t1;}
    for {set i 1} {$i<=3000} {incr i} {
      set r [expr {int(rand()*100000)}]
      puts $fd "INSERT INTO t1 VALUES($i,$r,'[number_name $r]');"
    }
    puts $fd {COMMIT;}
    close $fd
    run_test {A big DELETE followed by many small INSERTs}

    set fd [open $sql_file w]
    puts $fd {DROP TABLE t1;}
    puts $fd {DROP TABLE t2;}
    close $fd
    run_test {DROP TABLE}
}

proc read_file {name} {
    global target_dir
    set fd [open "$target_dir/.lumosql-work/$name" r]
    set data [read $fd]
    close $fd
    return [string trim $data]
}

# now run tests for each target

# signal -restart ignore SIGINT
for {set n_target 4} {$n_target < [llength $argv]} {incr n_target} {
    set target [lindex $argv $n_target]
    set target_dir "$build_dir/$target"

    # get information produced by the build process
    set title [read_file "title"]
    set sqlite_version [read_file "sqlite3_version"]
    set sqlite_id [read_file "sqlite3_commit_id"]
    set backend_name [read_file "backend_name"]
    set backend_version [read_file "backend_version"]
    set backend_id [read_file "backend_commit_id"]
    set build_target [read_file "build_target"]

    set target_db "$build_dir/$build_target/sqlite3/sqlite3"
    set sqlite_name [exec $target_db --version]

    puts "Target: $target ($title)"

    for {set n_run 0} {$n_run < $n_runs} {incr n_run} {
	if {$n_runs > 1} {
	    puts "RUN: $n_run"
	}

	# make sure we do have a run directory and it's empty
	if {[file exists $run_dir]} {
	    file delete -force -- $run_dir
	}
	file mkdir $run_dir

	# create benchmark result_db
	set sqlfd [open "| $target_db $run_dir/bench.db" w]
	puts $sqlfd {
	    PRAGMA default_synchronous=on;
	}
	    # Including the pragma below in the file above causes unknown operation error
	    # PRAGMA default_cache_size=2000;
	close $sqlfd

	set when_run [clock seconds]
	set run_id [exec $sqlite3_result $result_db {
	    select hex(sha3('$target' || randomblob(16) || '$when_run'));
	}]

	# log run data
	set sql_fd [open "| $sqlite3_result $result_db" w];
	puts $sql_fd "
	    insert into run_data (run_id, key, value)
	    values ('$run_id', 'when-run', $when_run);

	    insert into run_data (run_id, key, value)
	    values ('$run_id', 'sqlite-version', '$sqlite_version');

	    insert into run_data (run_id, key, value)
	    values ('$run_id', 'sqlite-id', '$sqlite_id');

	    insert into run_data (run_id, key, value)
	    values ('$run_id', 'target', '$target');

	    insert into run_data (run_id, key, value)
	    values ('$run_id', 'title', '$title');

	    insert into run_data (run_id, key, value)
	    values ('$run_id', 'sqlite-name', '$sqlite_name');
	"
	if {$backend_name != ""} {
	    puts $sql_fd "
		insert into run_data (run_id, key, value)
		values ('$run_id', 'backend-name', '$backend_name');

		insert into run_data (run_id, key, value)
		values ('$run_id', 'backend-version', '$backend_version');

		insert into run_data (run_id, key, value)
		values ('$run_id', 'backend', '$backend_name-$backend_version');

		insert into run_data (run_id, key, value)
		values ('$run_id', 'backend-id', '$backend_id');
	    "
	}

	# parse and log options
	set datasize ""
	for {set opt 1} \
	    {[file exists "$target_dir/.lumosql-work/option$opt"]} \
	    {incr opt} \
	{
	    set o [split [read_file "option$opt"] "\n"]
	    if {[llength $o] > 1} {
		set oname [lindex $o 0]
		set ovalue [lindex $o 1]
		puts $sql_fd "
		    insert into run_data (run_id, key, value)
		    values ('$run_id', 'option-$oname', '$ovalue');
		"
		if {$oname == "datasize"} {
		    set datasize $ovalue
		}
	    }
	}
	if {$datasize eq ""} {
	    set datasize 1
	    puts $sql_fd "
		insert into run_data (run_id, key, value)
		values ('$run_id', 'option-datasize', 1);
	    "
	}
	# if we leave $sql_fd open and the test is interrupted with a keyboard
	# interrupt, it seems to kill this sqlite3 too...
	close $sql_fd

	# and now go and run a set of tests
	run_tests

	# log run results
	set end_run [clock seconds]
	set sql_fd [open "| $sqlite3_result $result_db" w];
	puts $sql_fd "
	    insert into run_data (run_id, key, value)
	    values ('$run_id', 'tests-ok', '$tests_ok');

	    insert into run_data (run_id, key, value)
	    values ('$run_id', 'tests-intr', '$tests_intr');

	    insert into run_data (run_id, key, value)
	    values ('$run_id', 'tests-fail', '$tests_fail');

	    insert into run_data (run_id, key, value)
	    values ('$run_id', 'end-run', '$end_run');
	"
	close $sql_fd
	puts ""

	# it's nice to be clean
	file delete -force $run_dir
    }
}

