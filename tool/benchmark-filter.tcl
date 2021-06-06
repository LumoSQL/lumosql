#!/usr/bin/tclsh

# filter benchmark results based on various criteria; then display or copy them

# Copyright 2020 The LumoSQL Authors
#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2020 The LumoSQL Authors

# see documentation for full details of usage

###############################################################################
# initialise and parse options

set database ""
set import [list]
set sqlite3 ""

set out_list 0
set list_fields [list RUN_ID TARGET DATE TIME DURATION]
set out_summary 0
set out_add [list]
set out_export [list]
set out_copy [list]
set out_stats 0
set out_delete 0
set out_default 1

set limit 20
set average 0

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
set has_selection 0

proc optarg {re} {
    global o
    global a
    global argv
    incr a
    if {$a >= [llength $argv]} {
	puts stderr "Option $o requires a file name"
	exit 1
    }
    set oo $o
    set o [lindex $argv $a]
    if {! [regexp $re $o]} {
	puts stderr "Invalid argument for $o: $o"
	exit 1
    }
}

for {set a 0} {$a < [llength $argv]} {incr a} {
    set o [lindex $argv $a]
    if {$o eq "-db" || $o eq "-database"} {
	optarg {^}
	set database $o
    } elseif {$o eq "-import"} {
	optarg {^}
	lappend import $o
    } elseif {$o eq "-sqlite"} {
	optarg {^}
	set sqlite3 $o
    } elseif {$o eq "-limit"} {
	optarg {^\d+$}
	set limit $o
    } elseif {$o eq "-average"} {
	set average 1
    } elseif {$o eq "-list"} {
	set out_list 1
	set out_default 0
    } elseif {$o eq "-fields"} {
	optarg {^}
	set list_fields [split $o ,]
    } elseif {$o eq "-summary"} {
	set out_summary 1
	set out_default 0
    } elseif {$o eq "-details"} {
	set out_summary 2
	set out_default 0
    } elseif {$o eq "-export"} {
	optarg {^}
	lappend out_export $o
	set out_default 0
    } elseif {$o eq "-copy"} {
	optarg {^}
	lappend out_copy $o
	set out_default 0
    } elseif {[regexp {^[[:xdigit:]]{64}$} $o]} {
	lappend only_ids $o
	set has_selection 1
    } elseif {$o eq "-datasize"} {
	optarg {^\d+$}
	lappend only_option "datasize-$o"
	set has_selection 1
    } elseif {$o eq "-option"} {
	optarg {^\w+-}
	lappend only_option $o
	set has_selection 1
    } elseif {$o eq "-target"} {
	optarg {^}
	lappend only_targets $o
	set has_selection 1
    } elseif {$o eq "-version"} {
	optarg {^}
	lappend only_versions $o
	set has_selection 1
    } elseif {$o eq "-backend"} {
	optarg {^\w+(-.+)?$}
	lappend only_backends $o
	set has_selection 1
    } elseif {$o eq "-missing"} {
	optarg {^\w+$}
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
	optarg {^[-\w]+=}
	lappend out_add $o
	set out_default 0
    } elseif {$o eq "-delete"} {
	set out_delete 1
	set out_default 0
    } elseif {$o eq "-stats"} {
	set out_stats 1
	set out_default 0
    } else {
	puts stderr "Invalid option $o"
	exit 1
    }
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

# TODO if imports were specified, create a temporary database with the
# TODO imported runs, and replace $database to point at it, and also
# TODO remember to delete the temporary database at the end

if {! [file isfile $database]} {
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
    puts $sql "select run_id, 0"
    puts $sql "from test_data"
    puts $sql "where run_id not in"
    puts $sql "(select run_id from run_data)"
    puts $sql "union"
    # and also runs where there is the wrong number of backend keys
    puts $sql "select run_id, A"
    puts $sql "from"
    puts $sql "(select run_id, count(*) A"
    puts $sql "from run_data"
    puts $sql "where"
    puts $sql "key = 'backend' or key like 'backend-%'"
    puts $sql "group by run_id)"
    puts $sql "where A != 0 and A != 4"
    # TODO we could also count the tests and see that they match tests-ok, fail, intr
    # TODO any other thing we consider invalid?
} else {
    puts $sql "select run_id, value from run_data where key='when-run'"

    if {[llength $only_ids] > 0} {
	# restrict search to these IDs
	puts $sql "and run_id in ('[lindex $only_ids 0]'"
	for {set i 1} {$i < [llength $only_ids]} {incr i} {
	    puts $sql ", '[lindex $only_ids $i]'"
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
	    puts $sql "$or (key = 'sqlite-version' and value = '$val')"
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
	    if {[regexp {^\w+-} $val]} {
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
    if {$limit > 0} { puts $sql "limit [expr {$limit + 1}]" }
    puts $sql ";"
}

flush $sql

set fd [open "| $sqlite3 $database < $sql_file" r]
set rundict [dict create]
set runlist [list]
set excess 0
while {[gets $fd rv] >= 0} {
    set r [split $rv "|"]
    if {[llength $r] != 2} {
	puts stderr "Invalid data from $sqlite3: $rv"
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
	set out_summary 1
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
    foreach field $list_fields {
	if {$field eq "RUN_ID"} {
	    set width -64
	    lappend fmt "%-64s"
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
	} else {
	    puts stderr "Invalid field: $field"
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

if {$out_summary} {
    add_run_key "title"
    add_run_key "target"
    add_run_key "sqlite-name"
    add_test_op "duration" "real-time" "sum(value)"
    if {$out_summary > 1} {
	add_run_key "backend-name"
	add_run_key "backend-version"
	add_test_op "n-tests" "test-name" "count(*)"
    }
    set hdr ""
    set adj ""
    set dash "---"
    set times [list]
    set status [list]
    for {set i 0} {$i < [llength $runlist]} {incr i} {
	set run_id [lindex $runlist $i]
	if {[llength $runlist] > 1} {
	    set cn [expr {$i + 1}]
	    if {$out_summary < 2} { puts "Column $cn" }
	    append hdr [format "%11d " $cn]
	    append adj $dash
	    set dash "------"
	} else {
	    set hdr "       TIME "
	}
	set d [dict get $rundict $run_id]
	puts "Benchmark: [dict get $d "title"]"
	puts "   Target: [dict get $d "target"]"
	if {$out_summary > 1} {
	    puts "       ID: $run_id"
	    if {[dict exists $d "backend-name"]} {
		set v [dict get $d "backend-name"]
		if {[dict exists $d "backend-version"]} {
		    append v "-[dict get $d "backend-version"]"
		}
		puts "  Backend: $v"
	    }
	}
	puts "          ([dict get $d "sqlite-name"])"
	puts "   Ran at: [clock format [dict get $d "when-run"] -format "%Y-%m-%d %H:%M:%S"]"
	puts [format " Duration: %.3f" [dict get $d "duration"]]
	set nnames [get_test_key $run_id "test-name"]
	if {$out_summary > 1} {
	    # print more information about this run
	    set rd [get_run_data $run_id]
	    set options "  Options:"
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
		    set options "          "
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
		    puts [format "%9s: %s" $key $value]
		}
	    }
	    set n_tests [dict get $d "n-tests"]
	    puts "    Tests: $n_tests ($tests_ok OK, $tests_fail FAIL, $tests_intr Interrupted)"
	    if {$end_run > 0} {
		puts "   End at: [clock format $end_run -format "%Y-%m-%d %H:%M:%S"]"
	    }
	    # now show details of all tests
	    for {set tn 1; set tc 0} {$tc < $n_tests} {incr tn} {
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
		puts [format "        Duration: %.3f%s" [find $tdata "real-time"] $cpu]
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
		incr tc
	    }
	} else {
	    if {$i > 0} {
		if {! [list_eq $nnames $tnames]} {
		    puts stderr "Runs $run_id and [lindex $runlist 0] have different tests"
		    exit 1
		}
	    } else {
		set tnames $nnames
	    }
	    set ttimes [get_test_key $run_id "real-time"]
	    set tstatus [get_test_key $run_id "status"]
	    lappend times $ttimes
	    lappend status $tstatus
	}
	puts ""
    }
    if {$out_summary < 2} {
	if {[llength $runlist] > 1} { puts "${adj}-TIME$adj" }
	puts "${hdr}TEST NAME"
	for {set t 0} {$t < [llength $tnames]} {incr t} {
	    set r ""
	    for {set i 0} {$i < [llength $runlist]} {incr i} {
		set d [lindex [lindex $times $i] $t]
		set s [lindex [lindex $status $i] $t]
		if {$s eq "OK" || $s eq ""} {
		    append r [format "%11.3f " $d]
		} else {
		    append r [format "%11.11s " $s]
		}
	    }
	    puts "$r[format "%4d %s" [expr {$t + 1}] [lindex $tnames $t]]"
	}
	puts ""
    }
}

for {set a 0} {$a < [llength $out_export]} {incr a} {
    add_test_op "n-tests" "test-name" "count(*)"
    set fn [lindex $out_export $a]
    if {[file exists $fn]} {
	puts stderr "Will not overwrite file $fn"
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

for {set a 0} {$a < [llength $out_copy]} {incr a} {
    set dn [lindex $out_copy $a]
    # TODO copy to $dn
}

if {[llength $out_add] > 0} {
    # TODO we should check that the selected runs don't have any of these
    # TODO options already (and/or add a flag to overwrite them)
    set sql [file tempfile sql_file]
    for {set i 0} {$i < [llength $runlist]} {incr i} {
	set run_id [lindex $runlist $i]
	for {set j 0} {$j < [llength $out_add]} {incr j} {
	    regexp {^([-\w]+)=(.*)$} [lindex $out_add $j] -> opt val
	    puts $sql "insert into run_data (run_id, key, value)"
	    puts $sql "values ('$run_id', '$opt', '$val');"
	}
    }
    flush $sql
    exec $sqlite3 $database < $sql_file
    close $sql
    file delete $sql_file
}

if {$out_delete} {
    # TODO delete these runs from both tables
}

# TODO -stats                    summary statistics on all tests

if {$excess} {
    puts "FIlter returned more than $limit runs, list has been truncated"
}

exit 0

