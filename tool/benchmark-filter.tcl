#!/usr/bin/tclsh

# filter benchmark results based on various criteria; then display or copy them

# Copyright 2020 The LumoSQL Authors
#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2020 The LumoSQL Authors

# see documentation for full details of usage

###############################################################################

# Don't want to enforce a dependency on Tclx, but it is nice to have
if { ! [catch {package require Tclx 8.0}] }  {
    # eg if the user exits a "more" pipe early then do not crash
    signal trap SIGPIPE {exit 1}  
}

# initialise and parse options

set database ""
set import [list]
set sqlite3 ""

set out_list 0
set list_fields [list]
set list_tests [list]
set out_summary 0
set out_add [list]
set out_export [list]
set out_copy ""
set out_stats 0
set out_delete 0
set out_default 1
set out_column 0
set ignore_numbers 0

set limit 20
set average 0
set normalise 0

set only_failed 0
set only_interrupted 0
set only_completed 0
set only_crashed 0
set only_empty 0
set only_invalid 0
set only_missing [list]
set only_ids [list]
set only_targets [list]
set only_versions [list]
set only_backends [list]
set only_option [list]
set only_cpu [list]
set only_disk [list]
set has_selection 0


proc optarg {re what} {
    global o
    global a
    global argv
    incr a
    if {$a >= [llength $argv]} {
	puts stderr "Option $o requires a $what"
	exit 1
    }
    set oo $o
    set o [lindex $argv $a]
    if {! [regexp $re $o]} {
	puts stderr "Invalid argument for $oo: $o"
	exit 1
    }
}

proc optlist {var what {delim ""}} {
    global a
    global o
    global argv
    incr a
    set done 0
    upvar 1 $var LS
    while {$a < [llength $argv] && ! [regexp {^-} [lindex $argv $a]]} {
	incr done
	if {$delim eq ""} {
	    lappend LS [lindex $argv $a]
	} else {
	    foreach ap [split [lindex $argv $a] $delim] {
		lappend LS $ap
	    }
	}
	incr a
    }
    incr a -1
    if {$done == 0} {
	puts stderr "Option $o requires a $what"
	exit 1
    }
}

# This is a mild duplication of information, but simpler on the whole
proc display_help {} {
	puts stderr "                                                                                                  "
	puts stderr "     -db, -database     LumoSQL benchmark file                      /tmp/benchmark-data.sqlite    "
	puts stderr "     -count             return total number of runs                                               "
	puts stderr "     -import            read/convert files produced by -export      bench1 bench2                 "
	puts stderr "     -sqlite            path to a valid SQLite3 binary              ~/tmp/path/to/sqlite3         "
	puts stderr "     -limit             maximum number of SQL rows to return        50                            "
	puts stderr "     -average           average across all runs, per dimension      NOT IMPLEMENTED YET           "
	puts stderr "     -normalise         normalise test times against total run time                               "
	puts stderr "     -list              select list output (default if no filters selected)                       "
	puts stderr "     -fields            list of fields to return with -list         ARCH,OS,TARGET,DURATION       "
	puts stderr "     -quick             show sqlite+backend name as column headers for timings                    "
	puts stderr "     -summary           describe each column before returning all timings                         "
	puts stderr "     -details           return every field and row                                                "
	puts stderr "     -export            plain text dump of entire benchmark db                                    "
	puts stderr "     -copy              append selected run(s) to database          runs.sqlite                   "
	puts stderr "     -option                                                                                      "
	puts stderr "     -target                                                                                      "
	puts stderr "     -version           select runs with this sqlite version        3.37.0                        "
	puts stderr "     -backend           select runs with the specified backend      lmdb                          "
	puts stderr "                                                                    lmdb-0.9.29                   "
	puts stderr "     -no-backend        select runs with an unmodified sqlite                                     "
	puts stderr "     -missing                                                                                     "
	puts stderr "     -failed                                                                                      "
	puts stderr "     -completed         only return completed runs                                                "
	puts stderr "     -interrupted       only return interrupted runs                                              "
	puts stderr "     -crashed           only return crashed runs                                                  "
	puts stderr "     -empty             only return empty runs                                                    "
	puts stderr "     -invalid           only return invalid runs                                                  "
	puts stderr "     -add               add a column (?) to a benchmark db                                        "
	puts stderr "     -delete            delete specified runs from database(s)      NOT IMPLEMENTED YET           "
	puts stderr "     -stats             summary statistics for all runs             NOT IMPLEMENTED YET           "
}

for {set a 0} {$a < [llength $argv]} {incr a} {
    set o [lindex $argv $a]
    if {$o eq "-h" || $o eq "-help" || $o eq "-?"} {
	display_help
	exit 1
    } elseif {$o eq "-db" || $o eq "-database"} {
	optarg {^} "file name"
	set database $o
    } elseif {$o eq "-import"} {
	optlist import "list of files"
    } elseif {$o eq "-sqlite"} {
	optarg {^} "file name"
	set sqlite3 $o
    } elseif {$o eq "-limit"} {
	optarg {^\d+$} "number"
	set limit $o
    } elseif {$o eq "-average"} {
	set average 1
    } elseif {$o eq "-normalise" || $o eq "-normalize"} {
	set normalise 1
    } elseif {$o eq "-list"} {
	set out_list 1
	set out_default 0
    } elseif {$o eq "-fields"} {
	optlist list_fields "list of fields" ","
    } elseif {$o eq "-tests" || $o eq "-benchmarks"} {
	optlist list_tests "list of tests/benchmarks" ","
    } elseif {$o eq "-count"} {
	set out_summary -1
	set out_default 0
    } elseif {$o eq "-quick"} {
	set out_summary 1
	set out_default 0
    } elseif {$o eq "-summary"} {
	set out_summary 2
	set out_default 0
    } elseif {$o eq "-details"} {
	set out_summary 3
	set out_default 0
    } elseif {$o eq "-column"} {
	optarg {^(test|benchmark|target)$} "what goes into columns"
	if {$o eq "target"} {
	    set out_column 0
	} else {
	    set out_column 1
	}
    } elseif {$o eq "-ignore-numbers"} {
	set ignore_numbers 1
    } elseif {$o eq "-export"} {
	optarg {^} "file name"
	lappend out_export $o
	set out_default 0
    } elseif {$o eq "-copy"} {
	optarg {^} "file name"
	set out_copy $o
	set out_default 0
    } elseif {[regexp {^[[:xdigit:]]{8,64}$} $o]} {
	lappend only_ids $o
	set has_selection 1
    } elseif {$o eq "-datasize"} {
	optarg {^\d+(?:,\d+)$} "number"
	lappend only_option "datasize-$o"
	set has_selection 1
    } elseif {$o eq "-option"} {
	optarg {^\w+-} "option name and value"
	lappend only_option $o
	set has_selection 1
    } elseif {$o eq "-target"} {
	optarg {^} "target specification"
	lappend only_targets $o
	set has_selection 1
    } elseif {$o eq "-version"} {
	optarg {^} "version specification"
	lappend only_versions $o
	set has_selection 1
    } elseif {$o eq "-cpu" || $o eq "-cpu-comment"} {
	optarg {^} "cpu comment pattern"
	lappend only_cpu $o
	set has_selection 1
    } elseif {$o eq "-disk" || $o eq "-disk-comment"} {
	optarg {^} "disk comment pattern"
	lappend only_disk $o
	set has_selection 1
    } elseif {$o eq "-backend"} {
	optarg {^\w+(-.+)?$} "backend name and optional version"
	lappend only_backends $o
	set has_selection 1
    } elseif {$o eq "-no-backend"} {
	lappend only_backends ""
	set has_selection 1
    } elseif {$o eq "-missing"} {
	optarg {^\w+$} "keyword"
	lappend only_missing $o
	set has_selection 1
    } elseif {$o eq "-failed"} {
	set only_failed 1
	set has_selection 1
    } elseif {$o eq "-completed"} {
	set only_completed 1
	set has_selection 1
    } elseif {$o eq "-interrupted"} {
	set only_interrupted 1
	set has_selection 1
    } elseif {$o eq "-crashed"} {
	set only_crashed 1
	set has_selection 1
    } elseif {$o eq "-empty"} {
	set only_empty 1
	set has_selection 1
    } elseif {$o eq "-invalid"} {
	set only_invalid 1
	set has_selection 1
    } elseif {$o eq "-add"} {
	optarg {^[-\w]+=} "keyword and value"
	lappend out_add $o
	set out_default 0
    } elseif {$o eq "-delete"} {
	set out_delete 1
	set out_default 0
    } elseif {$o eq "-stats"} {
	set out_stats 1
	set out_default 0
   } else {
	puts stderr "Invalid option $o . Try -help"
	exit 1
    }
}

if {[llength $list_fields] == 0} {
    set list_fields [list RUN_ID TARGET DATE TIME DURATION]
}

if {$sqlite3 eq ""} {
    # if build.tcl provided a build info, use it to see if it points to a valid sqlite3
    if {[file isfile .build.info]} {
	set rd [open .build.info]
	set build_info [split [read $rd] \n]
	close $rd
	if {[llength $build_info] >= 2} {
	    set sqlite3_for_db [file join [lindex $build_info 0] [lindex $build_info 1] sqlite3]
	    if {[file executable $sqlite3_for_db]} {
		set sqlite3 $sqlite3_for_db
	    }
	}
    }
}

if {$sqlite3 eq ""} {
    # the above didn't see a valid sqlite3, look for one
    if {[file executable "build/3.35.3/sqlite3"]} {
	set sqlite3 "./build/3.35.3/sqlite3"
    } elseif {[file executable "build/3.34.1/sqlite3"]} {
	set sqlite3 "./build/3.34.1/sqlite3"
    } elseif {[file executable "build/3.33.1/sqlite3"]} {
	set sqlite3 "./build/3.33.1/sqlite3"
    } else {
	set has_version ""
	catch {
	    set has_version [exec "sqlite3" "-version"]
	}
	if {$has_version ne ""} {
	    # we have sqlite3 in path
	    set sqlite3 "sqlite3"
	} else {
	    puts stderr "Cannot find a working sqlite3"
	    exit 1
	}
    }
}

if {$database eq ""} {
    # if build.tcl provided a database info, use it to see if it points to a valid file
    if {[file isfile .benchdb.info]} {
	set rd [open .benchdb.info]
	set benchdb_info [split [read $rd] \n]
	close $rd
	if {[llength $benchdb_info] >= 1} {
	    set benchdb_info [lindex $benchdb_info 0]
	    if {[file readable $benchdb_info]} {
		set database $benchdb_info
	    }
	}
    }
}

if {$database eq ""} { set database "benchmarks.sqlite" }

proc make_database {name} {
    # XXX this is duplicate from build.tcl but it will do for now
    set run_schema {
	CREATE TABLE run_data (
	    run_id VARCHAR(128),
	    key VARCHAR(256),
	    value TEXT
	);
	CREATE UNIQUE INDEX run_data_index ON run_data (run_id, key);
    }
    set test_schema {
	CREATE TABLE test_data (
	    run_id VARCHAR(128),
	    test_number INTEGER,
	    key VARCHAR(256),
	    value TEXT
	);
	CREATE UNIQUE INDEX test_data_index_1 ON test_data (run_id, test_number, key);
	CREATE UNIQUE INDEX test_data_index_2 ON test_data (run_id, key, test_number);
    }
    global sqlite3
    set sqlfd [open "| $sqlite3 $name" w]
    puts $sqlfd $run_schema
    puts $sqlfd $test_schema
    close $sqlfd
}

# if imports were specified, create a temporary database with the
# imported runs, and replace $database to point at it, and also
# remember to delete the temporary database at the end
set database_orig ""
if {[llength $import] > 0} {
    set database_orig $database
    set tempdb [file tempfile database]
    close $tempdb
    file delete $database
    make_database $database
    set sqlfd [open "| $sqlite3 $database" w]
    foreach import $import {
	set impfd [open $import r]
	if {[gets $impfd line] < 0 || ! [regexp {LumoSQL.*benchmark.*data} $line]} {
	    puts stderr "$import: Invalid import file: invalid initial line"
	    close $sqlfd
	    file delete $database
	    exit 1
	}
	while {[gets $impfd line] >= 0} {
	    if {! [regexp {^([[:xdigit:]]{64}) (\d+)} $line -> run_id tests]} {
		puts stderr "$import: Invalid import file: invalid run start line ($line)"
		close $sqlfd
		file delete $database
		exit 1
	    }
	    set num 0
	    while {[gets $impfd line] >= 0} {
		if {$line eq ""} {break}
		if {[regexp {^--(\d+)} $line -> tnum]} {
		    incr num
		    if {$num != $tnum} {
			puts stderr "$import: Invalid import file: test $tnum out of sequence"
			close $sqlfd
			file delete $database
			exit 1
		    }
		    continue;
		}
		if {[regexp {^([-\w]+)\s+(.*)$} $line -> key value]} {
		    set qvalue [regsub -all {'} $value {''}]
		    if {$num == 0} {
			puts $sqlfd "INSERT INTO run_data (run_id, key, value) VALUES ('$run_id', '$key', '$qvalue');"
		    } else {
			puts $sqlfd "INSERT INTO test_data (run_id, test_number, key, value) VALUES ('$run_id', $num, '$key', '$value');"
		    }
		    continue
		}
		puts stderr "$import: Invalid input line ($line)";
		close $sqlfd
		file delete $database
		exit 1
	    }
	    if {$num != $tests} {
		puts stderr "$import: Invalid import file: expected $tests tests, found $num"
		close $sqlfd
		file delete $database
		exit 1
	    }
	}
	close $impfd
    }
    close $sqlfd
} elseif {! [file isfile $database]} {
    puts stderr "Database not found: $database"
    exit 1
}

###############################################################################
# select runs

set sql [file tempfile sql_file]

if ($only_invalid) {
    # this selects run IDs which are not valid in run_data: the only sensible
    # action for it is -delete and it makes no sense to combine it with any
    # of the other selections
    if {$out_summary < 0} {
	puts $sql "select count(*)"
    } else {
	puts $sql "select run_id, 0"
    }
    puts $sql "from test_data"
    puts $sql "where run_id not in"
    puts $sql "(select run_id from run_data)"
    # and also runs where there is the wrong number of backend keys
    if {$out_summary < 0} {
	puts $sql ";"
	puts $sql "select count(*)"
    } else {
	puts $sql "union"
	puts $sql "select run_id, A"
    }
    puts $sql "from"
    puts $sql "(select run_id, count(*) A"
    puts $sql "from run_data"
    puts $sql "where"
    puts $sql "key = 'backend' or key like 'backend-%'"
    puts $sql "group by run_id)"
    puts $sql "where A != 0 and A != 4 and A != 5"
    # TODO we could also count the tests and see that they match tests-ok, fail, intr
    # TODO any other thing we consider invalid?
} else {
    if {$out_summary < 0} {
	puts $sql "select count(*)"
    } else {
	puts $sql "select run_id, value"
    }
    puts $sql "from run_data where key='when-run'"

    if {[llength $only_ids] > 0} {
	# restrict search to these IDs
	set or "and ("
	for {set i 0} {$i < [llength $only_ids]} {incr i} {
	    set val [lindex $only_ids $i]
	    if {[string length $val] < 64} {
		puts $sql "$or run_id like '$val%'"
	    } else {
		puts $sql "$or run_id = '$val'"
	    }
	    set or "or"
	}
	puts $sql ")"
	# TODO run the sql so far and check that all the IDs are valid
    }

    if {[llength $only_option] > 0} {
	# restrict search to things which have these options
	puts $sql "and run_id in ("
	puts $sql "select run_id from run_data"
	set or "where"
	for {set i 0} {$i < [llength $only_option]} {incr i} {
	    regexp {^(\w+)-(.*)$} [lindex $only_option $i] -> opt val
	    puts $sql "$or (key = 'option-$opt' and value = '$val')"
	    set or "or"
	}
	puts $sql ")"
    }

    if {[llength $only_cpu] > 0} {
	# restrict search to things with a matching cpu-comment
	puts $sql "and run_id in ("
	puts $sql "select run_id from run_data"
	puts $sql "where key = 'cpu-comment'"
	puts $sql "and ("
	set or ""
	foreach dcom $only_cpu {
	    puts $sql "${or}value like '$dcom'"
	    set or " or "
	}
	puts $sql "))"
    }

    if {[llength $only_disk] > 0} {
	# restrict search to things with a matching disk-comment
	puts $sql "and run_id in ("
	puts $sql "select run_id from run_data"
	puts $sql "where key = 'disk-comment'"
	puts $sql "and ("
	set or ""
	foreach dcom $only_disk {
	    puts $sql "${or}value like '$dcom'"
	    set or " or "
	}
	puts $sql "))"
    }

    if {[llength $only_missing] > 0} {
	# restrict search to things which do not have a particular option
	# this is not a nice search... but we'll have to figure out a better one
	puts $sql "and run_id not in ("
	puts $sql "select run_id from run_data"
	set or "where"
	for {set i 0} {$i < [llength $only_missing]} {incr i} {
	    set opt [lindex $only_missing $i]
	    puts $sql "$or (key = 'option-$opt')"
	    set or "or"
	}
	puts $sql ")"
    }

    if {[llength $only_targets] > 0} {
	# restrict search to things which have these options
	puts $sql "and run_id in ("
	puts $sql "select run_id from run_data"
	set or "where"
	for {set i 0} {$i < [llength $only_targets]} {incr i} {
	    set val [lindex $only_targets $i]
	    puts $sql "$or (key = 'target' and value = '$val')"
	    set or "or"
	}
	puts $sql ")"
    }

    if {[llength $only_versions] > 0} {
	# restrict search to things which have these options
	puts $sql "and run_id in ("
	puts $sql "select run_id from run_data"
	set or "where"
	for {set i 0} {$i < [llength $only_versions]} {incr i} {
	    set val [lindex $only_versions $i]
	    puts $sql "$or ((key = 'sqlite-version' and value = '$val') or (key = 'sqlite-name' and value like '$val %'))"
	    set or "or"
	}
	puts $sql ")"
    }

    if {[llength $only_backends] > 0} {
	# restrict search to things which have these options
	puts $sql "and run_id in ("
	puts $sql "select run_id from run_data"
	set or "where"
	for {set i 0} {$i < [llength $only_backends]} {incr i} {
	    set val [lindex $only_backends $i]
	    if {$val eq ""} {
		# Uhm, select any run_id where there is no key 'backend',
		# is there a better query for it?
		puts $sql "$or (run_id in (select run_id from run_data where run_id not in (select run_id from run_data where key = 'backend')))"
	    } elseif {[regexp {^\w+-} $val]} {
		puts $sql "$or (key = 'backend' and value = '$val')"
	    } else {
		puts $sql "$or (key = 'backend-name' and value = '$val')"
	    }
	    set or "or"
	}
	puts $sql ")"
    }

    if {$only_failed} {
	puts $sql "and run_id in ("
	puts $sql "select run_id from run_data"
	puts $sql "where key='tests-fail'"
	puts $sql "and value > 0"
	puts $sql ")"
    }

    if {$only_interrupted} {
	puts $sql "and run_id in ("
	puts $sql "select run_id from run_data"
	puts $sql "where key='tests-intr'"
	puts $sql "and value > 0"
	puts $sql ")"
    }

    if {$only_completed} {
	puts $sql "and run_id in ("
	puts $sql "select run_id from run_data"
	puts $sql "where key='end-run'"
	puts $sql ")"
	puts $sql "and run_id in ("
	puts $sql "select run_id from run_data"
	puts $sql "where key='tests-intr'"
	puts $sql "and value == 0"
	puts $sql ")"
	puts $sql "and run_id in ("
	puts $sql "select run_id from run_data"
	puts $sql "where key='tests-fail'"
	puts $sql "and value == 0"
	puts $sql ")"
    }

    if {$only_crashed} {
	puts $sql "and run_id not in ("
	puts $sql "select run_id from run_data"
	puts $sql "where key='end-run'"
	puts $sql ")"
    }

    if {$only_empty} {
	puts $sql "and run_id not in ("
	puts $sql "select run_id from test_data"
	puts $sql ")"
    }

    puts $sql "order by value desc";
    if {$limit > 0 && $out_summary >= 0} {
	puts $sql "limit [expr {$limit + 1}]"
    }
    puts $sql ";"
}

flush $sql

set fd [open "| $sqlite3 $database < $sql_file" r]

if {$out_summary < 0} {
    set count 0
    while {[gets $fd rv] >= 0} { incr count $rv }
    puts $count
    close $sql
    file delete $sql_file
    exit 0
}

set rundict [dict create]
set runlist [list]
set excess 0
while {[gets $fd rv] >= 0} {
    set r [split $rv "|"]
    if {[llength $r] != 2} {
	puts stderr "Invalid data from $sqlite3: $rv"
	if {$database_orig ne ""} {file delete $database}
	exit 1
    }
    if {$limit > 0 && [llength $runlist] >= $limit} {
	incr excess
	continue
    }
    set run_id [lindex $r 0]
    dict set rundict $run_id [dict create when-run [lindex $r 1]]
    lappend runlist $run_id
}
close $fd

close $sql
file delete $sql_file

if {[llength $runlist] == 0} {
    puts stderr "No runs selected"
    if {$database_orig ne ""} {file delete $database}
    exit 1
}

# at some point we'll have other sorting options; for now, we sort by
# date/time ascending and we get that by just reversing the results
set runlist [lreverse $runlist]

###############################################################################
# if required, change tests to get averages

if {$average} {
    # TODO calculate averages in memory; we'll need to make up new run IDs
    # TODO  which could be "average-N" or something and we'll need to remember
    # TODO  the original run IDs if we need to look anything else up later
}

###############################################################################
# output and/or delete these runs

set sql_inrun "run_id in ('[join $runlist "', '"]')"
set runsql "select run_id, value from run_data where $sql_inrun"
set key_added [dict create]

proc add_run_key {key} {
    global rundict
    global runsql
    global sqlite3
    global database
    global key_added
    if {[dict exists $key_added $key]} { return }
    dict set key_added $key 0
    set sql [file tempfile sql_file]
    puts $sql $runsql
    puts $sql "and key='$key';"
    flush $sql
    set fd [open "| $sqlite3 $database < $sql_file" r]
    while {[gets $fd rv] >= 0} {
	set r [split $rv "|"]
	if {[llength $r] != 2} {
	    puts stderr "Invalid data from $sqlite3: $rv"
	    if {$database_orig ne ""} {file delete $database}
	    exit 1
	}
	set run_id [lindex $r 0]
	if {! [dict exists $rundict $run_id]} {
	    #puts stderr "Hmmm, sqlite3 returned an invalid run ID $run_id"
	    continue
	}
	dict set rundict $run_id \
	    [dict merge [dict get $rundict $run_id] [dict create $key [lindex $r 1]]]
    }
    close $fd
    close $sql
    file delete $sql_file
}

proc add_test_op {name key op} {
    global rundict
    global sql_inrun
    global sqlite3
    global database
    set sql [file tempfile sql_file]
    puts $sql "select run_id, $op"
    puts $sql "from test_data"
    puts $sql "where $sql_inrun"
    puts $sql "and key='$key'"
    puts $sql "group by run_id;"
    flush $sql
    set fd [open "| $sqlite3 $database < $sql_file" r]
    while {[gets $fd rv] >= 0} {
	set r [split $rv "|"]
	if {[llength $r] != 2} {
	    puts stderr "Invalid data from $sqlite3: $rv"
	    if {$database_orig ne ""} {file delete $database}
	    exit 1
	}
	set run_id [lindex $r 0]
	if {! [dict exists $rundict $run_id]} {
	    #puts stderr "Hmmm, sqlite3 returned an invalid run ID $run_id"
	    continue
	}
	dict set rundict $run_id \
	    [dict merge [dict get $rundict $run_id] [dict create $name [lindex $r 1]]]
    }
    close $fd
    close $sql
    file delete $sql_file
}

proc get_run_data {run_id} {
    global sqlite3
    global database
    set sql [file tempfile sql_file]
    puts $sql "select key, value"
    puts $sql "from run_data"
    puts $sql "where run_id='$run_id'"
    puts $sql "order by key;"
    flush $sql
    set fd [open "| $sqlite3 $database < $sql_file" r]
    set result [list]
    while {[gets $fd rv] >= 0} {
	set r [split $rv "|"]
	if {[llength $r] != 2} {
	    puts stderr "Invalid data from $sqlite3: $rv"
	    if {$database_orig ne ""} {file delete $database}
	    exit 1
	}
	lappend result $r
    }
    close $fd
    close $sql
    file delete $sql_file
    return $result
}

proc get_test_data {run_id test_no} {
    global sqlite3
    global database
    set sql [file tempfile sql_file]
    puts $sql "select key, value"
    puts $sql "from test_data"
    puts $sql "where run_id='$run_id'"
    puts $sql "and test_number=$test_no"
    puts $sql "order by key;"
    flush $sql
    set fd [open "| $sqlite3 $database < $sql_file" r]
    set result [list]
    while {[gets $fd rv] >= 0} {
	set r [split $rv "|"]
	if {[llength $r] != 2} {
	    puts stderr "Invalid data from $sqlite3: $rv"
	    if {$database_orig ne ""} {file delete $database}
	    exit 1
	}
	lappend result $r
    }
    close $fd
    close $sql
    file delete $sql_file
    return $result
}

proc get_test_key {run_id key} {
    global sqlite3
    global database
    set sql [file tempfile sql_file]
    puts $sql "select value"
    puts $sql "from test_data"
    puts $sql "where run_id='$run_id'"
    puts $sql "and key='$key'"
    puts $sql "order by test_number;"
    flush $sql
    set fd [open "| $sqlite3 $database < $sql_file" r]
    set result [list]
    while {[gets $fd rv] >= 0} {
	lappend result $rv
    }
    close $fd
    close $sql
    file delete $sql_file
    return $result
}

proc field_width {key min} {
    global rundict
    global key_added
    global runlist
    if {! [dict exists $key_added $key]} { return $min }
    for {set i 0} {$i < [llength $runlist]} {incr i} {
	set run_id [lindex $runlist $i]
	set d [dict get $rundict $run_id]
	if {[dict exists $d $key]} {
	    set kl [string length [dict get $d $key]]
	    if {$kl > $min} { set min $kl }
	}
    }
    return $min
}

if {$out_default} {
    if {$has_selection} {
	set out_summary 2
    } else {
	set out_list 1
    }
}

proc if_key {d key op defval} {
    if {[dict exists $d $key]} {
	set v [dict get $d $key]
	return [eval $op]
    } else {
	return $defval
    }
}

proc show_done {d} {
    if {[dict exists $d "end-run"]} {
	if {[dict get $d "tests-intr"] || [dict get $d "tests-fail"]} {
	    return "INTR"
	} else {
	    return "YES"
	}
    } else {
	return "NO"
    }
}

if {$out_list} {
    set fmt [list]
    set title ""
    set op [list]
    set flist [list TARGET TITLE SQLITE_NAME]
    foreach lfield $list_fields {
	set field [string toupper $lfield]
	if {$field eq "RUN_ID" || $field eq "ID"} {
	    set width -64
	    lappend fmt "%-64s"
	    lappend op {$run_id}
	} elseif {[regexp {^((?:RUN_)?ID):(\d+)} $field skip field prefix]} {
	    if {$prefix < 8} {set prefix 8}
	    if {$prefix > 64} {set prefix 64}
	    set width -$prefix
	    lappend fmt "%-$prefix.${prefix}s"
	    lappend op {$run_id}
	} elseif {[lsearch -exact $flist $field] >= 0} {
	    set lf [string map {_ -} [string tolower $field]]
	    add_run_key $lf
	    set width [string length $field]
	    for {set i 0} {$i < [llength $runlist]} {incr i} {
		set run_id [lindex $runlist $i]
		set d [dict get $rundict $run_id]
		if {$width < [string length [dict get $d $lf]]} {
		    set width [string length [dict get $d $lf]]
		}
	    }
	    set width -$width
	    lappend fmt "%${width}s"
	    lappend op "\[dict get \$d $lf\]"
	} elseif {$field eq "DATE"} {
	    set width -10
	    lappend fmt "%-10s"
	    lappend op {[clock format $w -format "%Y-%m-%d"]}
	} elseif {$field eq "TIME"} {
	    set width -8
	    lappend fmt "%-8s"
	    lappend op {[clock format $w -format "%H:%M:%S"]}
	} elseif {$field eq "END_DATE"} {
	    set width 10
	    lappend fmt "%10s"
	    add_run_key "end-run"
	    lappend op {[if_key $d "end-run" {clock format $v -format "%Y-%m-%d"} "-"]}
	} elseif {$field eq "END_TIME"} {
	    set width 8
	    lappend fmt "%8s"
	    add_run_key "end-run"
	    lappend op {[if_key $d "end-run" {clock format $v -format "%H:%M:%S"} "-"]}
	} elseif {$field eq "DONE"} {
	    set width -4
	    lappend fmt "%-4s"
	    add_run_key "end-run"
	    add_run_key "tests-intr"
	    add_run_key "tests-fail"
	    lappend op {[show_done $d]}
	} elseif {$field eq "OK" || $field eq "INTR" || $field eq "FAIL"} {
	    set fname "tests-[string tolower $field]"
	    set width 4
	    lappend fmt "%4d"
	    add_run_key $fname
	    lappend op "\[dict get \$d $fname\]"
	} elseif {$field eq "DURATION"} {
	    add_test_op "duration" "real-time" "sum(value)"
	    set width 11
	    lappend fmt "%11s"
	    lappend op {[if_key $d "duration" {format "%11.3f" $v} "-"]}
	} elseif {$field eq "DISK_COMMENT" || $field eq "DISK"} {
	    add_run_key "disk-comment"
	    set width -[field_width "disk-comment" [string length $field]]
	    lappend fmt "%${width}s"
	    lappend op {[dict get $d "disk-comment" ]}
	} elseif {$field eq "CPU_COMMENT" || $field eq "CPU"} {
	    add_run_key "cpu-comment"
	    set width -[field_width "cpu-comment" [string length $field]]
	    lappend fmt "%${width}s"
	    lappend op {[dict get $d "cpu-comment" ]}
	} elseif {$field eq "DISK_WRITE_TIME" || $field eq "DISK_TIME"} {
	    # disk-read-time seems to be the time it takes to get data
	    # off the disk cache and is not particularly useful; but
	    # disk-write-time does have a useful value
	    add_run_key "disk-write-time"
	    lappend fmt "%9.3f"
	    lappend op {[dict get $d "disk-write-time" ]}
	} elseif {$field eq "CPU_TYPE" || $field eq "ARCH"} {
	    add_run_key "cpu-type"
	    set width -[field_width "cpu-type" [string length $field]]
	    lappend fmt "%${width}s"
	    lappend op {[dict get $d "cpu-type" ]}
	} elseif {$field eq "OS_TYPE" || $field eq "OS"} {
	    add_run_key "os-type"
	    set width -[field_width "os-type" [string length $field]]
	    lappend fmt "%${width}s"
	    lappend op {[dict get $d "os-type" ]}
	} elseif {$field eq "N_TESTS"} {
	    set width 7
	    lappend fmt "%7d"
	    add_test_op "n-tests" "test-name" "count(*)"
	    lappend op {[dict get $d "n-tests" ]}
	} else {
	    puts stderr "Invalid field: $field"
	    if {$database_orig ne ""} {file delete $database}
	    exit 1
	}
	append title [format "  %${width}s" $field]
    }
    puts [string range $title 2 end]
    foreach run_id $runlist {
	set d [dict get $rundict $run_id]
	set w [dict get $d "when-run"]
	set line ""
	for {set f 0} {$f < [llength $fmt]} {incr f} {
	    eval "set elem [lindex $op $f]"
	    append line [format "  [lindex $fmt $f]" $elem]
	}
	puts [string range $line 2 end]
    }
}

proc list_eq {l1 l2} {
    if {[llength $l1] != [llength $l2]} { return 0 }
    for {set i 0} {$i < [llength $l1]} {incr i} {
	if {[lindex $l1 $i] ne [lindex $l2 $i]} { return 0 }
    }
    return 1
}

proc find {l key} {
    set i [lsearch -index 0 -exact -ascii $l $key]
    if {$i < 0} { return "" }
    return [lindex [lindex $l $i] 1]
}

if {$out_summary > 0 && $out_summary < 3} {
    # check all tests are equal
    for {set i 0} {$i < [llength $runlist]} {incr i} {
	set run_id [lindex $runlist $i]
	if {$ignore_numbers} {
	    set nnames [list]
	    foreach tname [get_test_key $run_id "test-name"] {
		lappend nnames [regsub -all {\d+} $tname "#"]
	    }
	} else {
	    set nnames [get_test_key $run_id "test-name"]
	}
	if {$i > 0} {
	    if {! [list_eq $nnames $tnames]} {
		puts stderr "Runs $run_id and [lindex $runlist 0] have different tests"
		if {$database_orig ne ""} {file delete $database}
		exit 1
	    }
	} else {
	    set tnames $nnames
	}
    }
    set has_totals 1
    if {[llength $list_tests] > 0} {
	set show_tests [list]
	for {set c 1} {$c <= [llength $tnames]} {incr c} {
	    if {[lsearch -exact $list_tests $c] < 0} {
		lappend show_tests 0
	    } else {
		lappend show_tests 1
	    }
	}
	if {[lsearch -nocase -glob $list_tests "t*"] < 0} {
	    set has_totals 0
	}
    }
}

if {$out_column && $out_summary && $out_summary < 3} {
    add_run_key "target"
    add_test_op "duration" "real-time" "sum(value)"
    # determine length of all columns
    set maxlen [list]
    for {set t 0} {$t <= [llength $tnames]} {incr t} {
	lappend maxlen [string length $t]
    }
    for {set i 0} {$i < [llength $runlist]} {incr i} {
	set run_id [lindex $runlist $i]
	set ttimes [get_test_key $run_id "real-time"]
	set tstatus [get_test_key $run_id "status"]
	set tduration [dict get [dict get $rundict $run_id] "duration"]
	for {set t 0} {$t < [llength $tnames]} {incr t} {
	    if {[llength $list_tests] > 0 && ! [lindex $show_tests $t]} {
		continue;
	    }
	    set d [lindex $ttimes $t]
	    set s [lindex $tstatus $t]
	    if {$s eq "OK" || $s eq ""} {
		if {$normalise} {
		    set s [format "%.1f" [expr {$d * 1000.0 / $tduration}]]
		} else {
		    set s [format "%.3f" $d]
		}
	    }
	    if {[string length $s] > [lindex $maxlen $t]} {
		lset maxlen $t [string length $s]
	    }
	}
	set t [llength $tnames]
	set s [format "%.3f" $tduration]
	if {[string length $s] > [lindex $maxlen $t]} {
	    lset maxlen $t [string length $s]
	}
    }
    # use maxlen to determine column formats, and also
    # print headings (note that we don't do anything special
    # for -quick here, although this could change)
    set tfmt [list]
    set efmt [list]
    set header ""
    if {$normalise} {
	set dfmt "1f"
    } else {
	set dfmt "3f"
    }
    for {set t 0; set c 1} {$t < [llength $tnames]} {incr t; incr c} {
	lappend tfmt "%[lindex $maxlen $t].$dfmt "
	lappend efmt "%[lindex $maxlen $t]s "
	if {[llength $list_tests] > 0 && ! [lindex $show_tests $t]} {
	    continue;
	}
	append header [format "%[lindex $maxlen $t]d " $c]
	if {$t < [llength $tnames]} {
	    puts "Column $c: [lindex $tnames $t]"
	}
    }
    if {$has_totals && ! $normalise} {
	puts "Column T: Total run duration"
	append header [format "%[lindex $maxlen end]s " "T"]
	set fmt_totals "%[lindex $maxlen end].3f "
    }
    puts ""
    puts "${header}Target"
    for {set i 0} {$i < [llength $runlist]} {incr i} {
	set run_id [lindex $runlist $i]
	set d [dict get $rundict $run_id]
	set ttimes [get_test_key $run_id "real-time"]
	set tstatus [get_test_key $run_id "status"]
	set tduration [dict get $d "duration"]
	set line ""
	for {set t 0} {$t < [llength $tnames]} {incr t} {
	    if {[llength $list_tests] > 0 && ! [lindex $show_tests $t]} {
		continue;
	    }
	    set n [lindex $ttimes $t]
	    set s [lindex $tstatus $t]
	    if {$s eq "OK" || $s eq ""} {
		if {$normalise} {
		    append line [format [lindex $tfmt $t] [expr {$n * 1000.0 / $tduration}]]
		} else {
		    append line [format [lindex $tfmt $t] $n]
		}
	    } else {
		append line [format [lindex $efmt $t] $s]
	    }
	}
	if {$has_totals && ! $normalise} {
	    append line [format $fmt_totals $tduration]
	}
	puts "$line[dict get $d {target}]"
    }
    if {$excess} {
	puts ""
	puts "FIlter returned more than $limit runs, list has been truncated"
	puts "Use: -limit NUMBER to change the limit, or: -limit 0 to show all"
    }
    exit
}

if {$out_summary} {
    add_run_key "title"
    add_run_key "target"
    add_run_key "sqlite-name"
    add_run_key "sqlite-version"
    add_test_op "duration" "real-time" "sum(value)"
    add_run_key "backend-name"
    add_run_key "backend-version"
    add_run_key "disk-read-time"
    add_run_key "disk-write-time"
    if {$out_summary > 1} {
	add_test_op "n-tests" "test-name" "count(*)"
	set xspace "    "
    } else {
	set xspace ""
    }
    set hdr ""
    set adj ""
    set dash "--"
    set tgt1 ""
    set tgt2 ""
    set tgt3 ""
    set times [list]
    set status [list]
    for {set i 0} {$i < [llength $runlist]} {incr i} {
	set run_id [lindex $runlist $i]
	if {[llength $runlist] > 1} {
	    set cn [expr {$i + 1}]
	    if {$out_summary == 2} {
		puts "Column $cn"
	    }
	    append hdr [format "%11d " $cn]
	    append adj $dash
	    set dash "------"
	} else {
	    set hdr "$xspace   TIME "
	}
	set d [dict get $rundict $run_id]
	if {$out_summary > 1} {
	    puts "${xspace}Benchmark: [dict get $d "title"]"
	    puts "$xspace   Target: [dict get $d "target"]"
	    if {$out_summary > 2} {
		puts "$xspace       ID: $run_id"
		if {[dict exists $d "backend-name"]} {
		    set v [dict get $d "backend-name"]
		    if {[dict exists $d "backend-version"]} {
			append v "-[dict get $d "backend-version"]"
		    }
		    puts "$xspace  Backend: $v"
		}
	    }
	    puts "$xspace          ([dict get $d "sqlite-name"])"
	    puts "$xspace   Ran at: [clock format [dict get $d "when-run"] -format "%Y-%m-%d %H:%M:%S"]"
	    set tduration [dict get $d "duration"]
	    puts [format "$xspace Duration: %.3f" $tduration]
	    if {[dict exists $d "disk-read-time"] || [dict exists $d "disk-write-time"]} {
		set dt ""
		set sp ""
		if {[dict exists $d "disk-read-time"]} {
		    append dt [format "%sread: %.3f" $sp [dict get $d "disk-read-time"]]
		    set sp "; "
		}
		if {[dict exists $d "disk-write-time"]} {
		    append dt [format "%swrite: %.3f" $sp [dict get $d "disk-write-time"]]
		    set sp "; "
		}
		puts "${xspace}Disk time: $dt"
	    }
	} else {
	    append tgt1 [format "%11s " [dict get $d "sqlite-version"]]
	    if {[dict exists $d "backend-name"]} {
		append tgt2 [format "%11s " [dict get $d "backend-name"]]
	    } else {
		append tgt2 "            "
	    }
	    if {[dict exists $d "backend-version"]} {
		append tgt3 [format "%11s " [dict get $d "backend-version"]]
	    } else {
		append tgt3 "            "
	    }
	}
	set nnames [get_test_key $run_id "test-name"]
	if {$out_summary > 2} {
	    # print more information about this run
	    set rd [get_run_data $run_id]
	    set options "      Options:"
	    set tests_ok 0
	    set tests_fail 0
	    set tests_intr 0
	    set end_run 0
	    for {set j 0} {$j < [llength $rd]} {incr j} {
		set rp [lindex $rd $j];
		set key [lindex $rp 0];
		set value [lindex $rp 1];
		if {[string compare -length 7 $key "option-"] == 0} {
		    puts "$options [string range $key 7 end]-$value"
		    set options "              "
		} elseif {$key eq "tests-ok"} {
		    set tests_ok $value
		} elseif {$key eq "tests-intr"} {
		    set tests_intr $value
		} elseif {$key eq "tests-fail"} {
		    set tests_fail $value
		} elseif {$key eq "end-run"} {
		    set end_run $value
		} elseif {
		    $key ne "backend-id" &&
		    $key ne "backend-name" &&
		    $key ne "backend-version" &&
		    $key ne "sqlite-id" &&
		    $key ne "sqlite-name" &&
		    $key ne "sqlite-version" &&
		    $key ne "target" &&
		    $key ne "title" &&
		    $key ne "when-run" } \
		{
		    puts [format "%13s: %s" $key $value]
		}
	    }
	    set n_tests [dict get $d "n-tests"]
	    puts "    Tests: $n_tests ($tests_ok OK, $tests_fail FAIL, $tests_intr Interrupted)"
	    if {$end_run > 0} {
		puts "   End at: [clock format $end_run -format "%Y-%m-%d %H:%M:%S"]"
	    }
	    # now show details of all tests
	    for {set tn 1; set tc 0} {$tc < $n_tests} {incr tc; incr tn} {
		set tdata [get_test_data $run_id $tn]
		if {[llength $tdata] == 0} { continue }
		puts [format "%9s: %s" "Test $tn" [lindex $nnames [expr {$tn - 1}]]]
		puts "          Status: [find $tdata "status"]"
		set cpu ""
		set uc [find $tdata "user-cpu-time"]
		if {$uc ne ""} { 
		    set sc [find $tdata "system-cpu-time"]
		    if {$sc ne ""} { set sc [format " + system %.3f" $sc] }
		    append cpu [format " (user %.3f%s)" $uc $sc]
		}
		set rtime [find $tdata "real-time"]
		if {$normalise} {
		    set ntime [format " (%.1f)" [expr {$rtime * 1000.0 / $tduration}]]
		} else {
		    set ntime ""
		}
		puts [format "        Duration: %.3f%s%s" $rtime $ntime $cpu]
		for {set t 0} {$t < [llength $tdata]} {incr t} {
		    set rp [lindex $tdata $t];
		    set key [lindex $rp 0];
		    set value [lindex $rp 1];
		    if {
			$key ne "real-time" &&
			$key ne "status" &&
			$key ne "system-cpu-time" &&
			$key ne "test-name" &&
			$key ne "user-cpu-time" } \
		    {
			puts [format "       %9s: %s" $key $value]
		    }
		}
	    }
	} else {
	    set ttimes [get_test_key $run_id "real-time"]
	    set tstatus [get_test_key $run_id "status"]
	    lappend times $ttimes
	    lappend status $tstatus
	}
	if {$out_summary > 1} {
	    puts ""
	}
    }
    if {$out_summary < 3} {
	if {$out_summary > 1} {
	    if {[llength $runlist] > 1} { puts "-$adj TIME $adj" }
	    puts "${hdr}TEST NAME"
	} else {
	    puts "${tgt1}(sqlite version)"
	    puts "${tgt2}(backend name)"
	    puts "${tgt3}(backend version)"
	    puts "-$adj TIME $adj TEST NAME"
	}
	for {set t 0; set c 1} {$t < [llength $tnames]} {incr t; incr c} {
	    if {[llength $list_tests] > 0 && ! [lindex $show_tests $t]} {
		continue;
	    }
	    set r ""
	    for {set i 0} {$i < [llength $runlist]} {incr i} {
		set d [lindex [lindex $times $i] $t]
		set s [lindex [lindex $status $i] $t]
		if {$s eq "OK" || $s eq ""} {
		    if {$normalise} {
			append r [format "%11.1f " [expr {$d * 1000.0 / $tduration}]]
		    } else {
			append r [format "%11.3f " $d]
		    }
		} else {
		    append r [format "%11.11s " $s]
		}
	    }
	    puts "$r[format "%4d %s" $c [lindex $tnames $t]]"
	}
	if {$has_totals && ! $normalise} {
	    puts [string repeat "-" [string length $hdr]]
	    set r ""
	    for {set i 0} {$i < [llength $runlist]} {incr i} {
		set run_id [lindex $runlist $i]
		set d [dict get $rundict $run_id]
		append r [format "%11.3f " [dict get $d "duration"]]
	    }
	    puts "${r}(total benchmark run time)"
	}
	puts ""
    }
}

for {set a 0} {$a < [llength $out_export]} {incr a} {
    add_test_op "n-tests" "test-name" "count(*)"
    set fn [lindex $out_export $a]
    if {[file exists $fn]} {
	puts stderr "Will not overwrite file $fn"
	if {$database_orig ne ""} {file delete $database}
	exit 1
    }
    set fd [open $fn w]
    puts $fd "# LumoSQL benchmark data version 0.0"
    for {set i 0} {$i < [llength $runlist]} {incr i} {
	set run_id [lindex $runlist $i]
	set d [dict get $rundict $run_id]
	set n_tests [dict get $d "n-tests"]
	puts $fd "$run_id $n_tests"
	set rd [get_run_data $run_id]
	for {set j 0} {$j < [llength $rd]} {incr j} {
	    set rp [lindex $rd $j];
	    set key [lindex $rp 0];
	    set value [lindex $rp 1];
	    puts $fd "$key $value"
	}
	for {set tn 1; set tc 0} {$tc < $n_tests} {incr tn} {
	    set tdata [get_test_data $run_id $tn]
	    if {[llength $tdata] == 0} { continue }
	    puts $fd "--$tn"
	    for {set t 0} {$t < [llength $tdata]} {incr t} {
		set rp [lindex $tdata $t];
		set key [lindex $rp 0];
		set value [lindex $rp 1];
		puts $fd "$key $value"
	    }
	    incr tc
	}
	puts $fd ""
    }
    close $fd
}

if {[llength $out_add] > 0} {
    # TODO we should check that the selected runs don't have any of these
    # TODO options already (and/or add a flag to overwrite them)
    set sql [file tempfile sql_file]
    for {set i 0} {$i < [llength $runlist]} {incr i} {
	set run_id [lindex $runlist $i]
	for {set j 0} {$j < [llength $out_add]} {incr j} {
	    regexp {^([-\w]+)=(.*)$} [lindex $out_add $j] -> opt val
	    puts $sql "delete from run_data where"
	    puts $sql "run_id = '$run_id' and key = '$opt' and value = '';"
	    puts $sql "insert into run_data (run_id, key, value)"
	    puts $sql "values ('$run_id', '$opt', '$val');"
	}
    }
    flush $sql
    exec $sqlite3 $database < $sql_file
    close $sql
    file delete $sql_file
}

if {$out_copy ne ""} {
    # copy all runs to $out_copy, creating the tables if the file does not exist
    set qout_copy [regsub -all {'} $out_copy {''}]
    set qdatabase [regsub -all {'} $database {''}]
    if {[file exists $out_copy]} {
	set sql [file tempfile sql_file]
	puts $sql "ATTACH '$qout_copy' as NEW;"
	puts $sql "SELECT run_id FROM NEW.run_data WHERE run_id IN ("
	for {set i 0} {$i < [llength $runlist]} {incr i} {
	    if {$i} { puts $sql "," }
	    puts $sql "'[lindex $runlist $i]'"
	}
	puts $sql ") GROUP BY run_id limit 21;"
	flush $sql
	set fd [open "| $sqlite3 $database < $sql_file" r]
	set listed 0
	while {[gets $fd ri] >= 0} {
	    if {! $listed} {
		puts "The following run ID(s) are already present in $out_copy:"
	    }
	    incr listed
	    if {$listed > 20} {
		puts "... (more IDs omitted)"
	    } else {
		puts $ri
	    }
	}
	close $fd
	close $sql
	file delete $sql_file
	if {$listed} { exit 1}
    } else {
	make_database $out_copy
    }
    set sql [file tempfile sql_file]
    puts $sql "ATTACH '$qout_copy' as NEW;"
    puts $sql "ATTACH '$qdatabase' as OLD;"
    puts $sql "BEGIN;"
    for {set i 0} {$i < [llength $runlist]} {incr i} {
	set run_id [lindex $runlist $i]
	puts $sql "INSERT INTO NEW.run_data select * FROM OLD.run_data WHERE run_id='$run_id';"
	puts $sql "INSERT INTO NEW.test_data select * FROM OLD.test_data WHERE run_id='$run_id';"
    }
    puts $sql "COMMIT;"
    flush $sql
    exec $sqlite3 < $sql_file
    close $sql
    file delete $sql_file
}

if {$out_delete} {
    # TODO delete these runs from both tables
}

# TODO -stats                    summary statistics on all tests

if {$excess} {
    puts "FIlter returned more than $limit runs, list has been truncated"
    puts "Use: -limit NUMBER to change the limit, or: -limit 0 to show all"
}

if {$database_orig ne ""} {file delete $database}
exit 0

