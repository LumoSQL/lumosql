#!/usr/bin/tclsh
#
# Run this script using TCLSH to parse a lumosql target string
#
# Copyright 2020 The LumoSQL Authors under the terms contained in LICENSES/MIT
#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2020 The LumoSQL Authors
#
# /tool/parse-target.tcl

if {[llength $argv] != 3} {
  puts stderr "Usage: parse-target.tcl TARGET SOURCES_DIR WORK_DIR"
  exit 1
}

set target [lindex $argv 0]
set sources_dir [lindex $argv 1]
set work_dir [lindex $argv 2]

set tlist [split $target "+"]
if {[llength $tlist] < 1} {
    puts stderr "Invalid target $target"
    exit 1
}

# parse the first two components which are always sqlite version and
# (optional) backend name and version
set sqlite_version [lindex $tlist 0]
set backend_name ""
set backend_version ""
set title "sqlite $sqlite_version"
set build_target $sqlite_version
if {[llength $tlist] > 1 && [lindex $tlist 1] != ""} {
    set blist [regexp -inline {^([^-]+)-(.*)$} [lindex $tlist 1]]
    if {[llength $blist] < 2} {
	puts stderr "Invalid backend name-version"
	exit 1
    }
    set backend_name [lindex $blist 1]
    set backend_version [lindex $blist 2]
#    if {! [file isdirectory "$sources_dir/$backend_name"]} {
#	puts stderr "Invalid backend name $backend_name"
#	exit 1
#    }
    if {[string equal $sqlite_version ""]} {
	set title "$backend_name $backend_version"
    } else {
	append title " with $backend_name $backend_version"
    }
    append build_target "+$backend_name-$backend_version"
} else {
    if {[string equal $sqlite_version ""]} {
	puts stderr "Invalid TARGET: sqlite3 and backend both missing"
	exit 1
    }
}

set fd [open "$work_dir/sqlite3_version" w]
puts $fd $sqlite_version
close $fd

set fd [open "$work_dir/backend_name" w]
puts $fd $backend_name
close $fd

set fd [open "$work_dir/backend_version" w]
puts $fd $backend_version
close $fd

set fd [open "$work_dir/title" w]
puts $fd $title
close $fd

# and now parse remaining options
set opt_debug 0
set opt_datasize 1
for {set i 2} {$i < [llength $tlist]} {incr i} {
    set olist [regexp -inline {^([^-]+)-(.*)$} [lindex $tlist $i]]
    if {[llength $olist] < 3} {
	puts stderr "Invalid option [lindex $tlist $i]"
	exit 1
    }
    set oname [lindex $olist 1]
    set ovalue [lindex $olist 2]
    if {[string equal $oname "datasize"]} {
	if {[regexp {^\d+$} $ovalue]} {
	    set opt_datasize $ovalue
	} else {
	    puts stderr "Invalid value for datasize: $ovalue"
	    exit 1
	}
    } elseif {[string equal $oname "debug"]} {
	if {[string compare -nocase $ovalue "on"] == 0} {
	    set opt_debug 1
	} elseif {[string compare -nocase $ovalue "off"] == 0} {
	    set opt_debug 0
	} else {
	    puts stderr "Invalid value for debug: $ovalue"
	    exit 1
	}
    } else {
	puts stderr "Invalid option $oname"
	exit 1
    }
}

# create option files
set o 1
if {$opt_debug > 0} {
    append build_target "+debug-on"
    set fd [open "$work_dir/option$o" w]
    puts $fd "debug"
    puts $fd "on"
    close $fd
    incr o
}
set benchmark_target $build_target
if {$opt_datasize > 1} {
    append benchmark_target "+datasize-$opt_datasize"
    set fd [open "$work_dir/option$o" w]
    puts $fd "datasize"
    puts $fd $opt_datasize
    close $fd
    incr o
}

# make sure to clean up any leftover options from previous builds
while {[file exists "$work_dir/option$o"]} {
    file delete "$work_dir/option$o"
    incr o
}

set fd [open "$work_dir/build_target" w]
puts $fd $build_target
close $fd

set fd [open "$work_dir/benchmark_target" w]
puts $fd $benchmark_target
close $fd

