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

if {[llength $argv] != 2} {
  puts stderr "Usage: parse-target.tcl TARGET DIRECTORY"
  exit 1
}

set target [lindex $argv 0]
set dir [lindex $argv 1]

set tlist [split $target "+"]
if {[llength $tlist] < 1} {
    puts stderr "Invalid target $target"
    exit 1
}

set sqlite_version [lindex $tlist 0]
set backend_name ""
set backend_version ""
set title "sqlite $sqlite_version"
if {[llength $tlist] > 1 && [lindex $tlist 1] != ""} {
    set blist [regexp -inline {^([^-]+)-(.*)$} [lindex $tlist 1]]
    if {[llength $blist] < 2} {
	puts stderr "Invalid backend name-version"
	exit 1
    }
    set backend_name [lindex $blist 1]
    set backend_version [lindex $blist 2]
    append title " with $backend_name $backend_version"
}

set fd [open "$dir/sqlite3_version" w]
puts $fd $sqlite_version
close $fd

set fd [open "$dir/backend_name" w]
puts $fd $backend_name
close $fd

set fd [open "$dir/backend_version" w]
puts $fd $backend_version
close $fd

set fd [open "$dir/title" w]
puts $fd $title
close $fd

set o 0
for {set i 2} {$i < [llength $tlist]} {incr i} {
    incr o
    set olist [regexp -inline {^([^-]+)-(.*)$} [lindex $tlist $i]]
    set fd [open "$dir/option$o" w]
    for {set n 1} {$n < [llength $olist]} {incr n} {
	puts $fd [lindex $olist $n]
    }
    close $fd
}

