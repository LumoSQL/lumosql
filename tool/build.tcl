#!/usr/bin/tclsh

# TODO replace "system" with something which checks status

# LumoSQL build and benchmark

# Copyright 2020 The LumoSQL Authors, see LICENSES/MIT
#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2020 The LumoSQL Authors
# SPDX-ArtifactOfProjectName: LumoSQL
# SPDX-FileType: Tcl Script
# SPDX-FileComment: Original by Claudio Calvelli, December 2020

# For full details see documentation in the LumoSQL source tree
# at doc/lumo-build-benchmark.md .
#
# Executive summary:

# build.tcl OPERATION NOTFORK_CONFIG ARGUMENTS

# OPERATION: options
# ARGUMENTS: OUTPUT_FILE
#            create a Makefile fragment so that "make" can accept
#            command-line options corresponding to build options

# OPERATION: database
# ARGUMENTS: BUILD_DIR DATABASE_NAME
#            create database

# OPERATION: what
# ARGUMENTS: BUILD_OPTIONS
#            show what targets/options have been selected based on command-line

# OPERATION: build
# ARGUMENTS: BUILD_DIR BUILD_OPTIONS
#            build LumoSQL, if necessary

# OPERATION: benchmark
# ARGUMENTS: BUILD_DIR DATABASE_NAME BUILD_OPTIONS
#            run benchmarks

package require Tclx 8.0

if {[llength $argv] < 2} {
    puts stderr "Usage: build.tcl OPERATION NOTFORK_CONFIG ARGUMENTS"
    puts stderr "See documentation for more information"
    exit 1
}

set operation [lindex $argv 0]
set notfork [lindex $argv 1]
set prn 0

if {$operation eq "options"} {
    if {[llength $argv] != 3} {
	puts stderr "Usage: build.tcl options NOTFORK_CONFIG OUTPUT_FILE"
	exit 1
    }
    set outname [lindex $argv 2]
    set argp 3
    set outf [open "$outname.tmp" w]
    puts $outf "BUILD_OPTIONS :="
    puts $outf ""
    set prn 1
} elseif {$operation eq "database"} {
    if {[llength $argv] != 4} {
	puts stderr "Usage: build.tcl database NOTFORK_CONFIG BUILD_DIR DATABASE_NAME"
	exit 1
    }
    set build_dir [lindex $argv 2]
    set database_name [lindex $argv 3]
    set argp 4
} elseif {$operation eq "what"} {
    set argp 2
} elseif {$operation eq "build"} {
    if {[llength $argv] < 3} {
	puts stderr "Usage: build.tcl build NOTFORK_CONFIG BUILD_DIR BUILD_OPTIONS..."
	exit 1
    }
    set build_dir [lindex $argv 2]
    set argp 3
} elseif {$operation eq "benchmark"} {
    if {[llength $argv] < 4} {
	puts stderr "Usage: build.tcl benchmark NOTFORK_CONFIG BUILD_DIR DATABASE_NAME BUILD_OPTIONS..."
	exit 1
    }
    set build_dir [lindex $argv 2]
    set database_name [lindex $argv 3]
    set argp 4
} else {
    puts stderr "Invalid OPERATION [lindex $argv 0]"
    exit 1
}

# read not-forking configuration

if {! [file isdirectory $notfork]} {
    puts stderr "Configuration directory $notfork not found"
    exit 1
}

proc read_versions {ver_file backend vname dname} {
    set rf [open $ver_file r]
    upvar $vname vlist
    if {$dname ne ""} { upvar $dname dver }
    foreach ln [split [read $rf] \n] {
	regsub {^\s+} $ln "" ln
	regsub {\s+$} $ln "" ln
	if {$ln eq ""} { continue }
	if {[regexp {^#} $ln]} { continue }
	if {$backend eq ""} {
	    set target $ln
	} elseif { [regexp {^=\s*(.*)$} $ln skip dver] } {
	    continue
	} else {
	    set lx [split $ln "+"]
	    if {$lx < 2} {
		set sqlite3_version $dver
		set backend_version $ln
	    } else {
		set sqlite3_version [lindex $lx 0]
		set backend_version [lindex $lx 1]
	    }
	    set target "$sqlite3_version+$backend-$backend_version"
	}
	if {[lsearch -exact $vlist $target] < 0} {
	    lappend vlist $target
	}
    }
    close $rf
}

proc read_standalone {stand_file backend bname} {
    set rf [open $stand_file r]
    upvar $bname blist
    foreach ln [split [read $rf] \n] {
	regsub {^\s+} $ln "" ln
	regsub {\s+$} $ln "" ln
	if {$ln eq ""} { continue }
	if {[regexp {^#} $ln]} { continue }
	set vn [split $ln]
	if {[llength $vn] != 2} {
	    puts stderr "$stand_file: Invalid version number $ln"
	    exit 1
	}
	set backend_version [lindex $vn 0]
	set sqlite3_version [lindex $vn 1]
	set target "+$backend-$backend_version=$sqlite3_version"
	if {[lsearch -exact $blist $target] < 0} {
	    lappend blist $target
	}
    }
    close $rf
}

proc set_bool {var val} {
    upvar $var result
    if {[regexp ^\d+$ $val]} {
	if {$val} {
	    set result 1
	} else {
	    set result 0
	}
    } elseif {$val eq "no" || $val eq "off" || $val eq "false"} {
	set result 0
    } elseif {$val eq "yes" || $val eq "on" || $val eq "true"} {
	set result 1
    } else {
	puts stderr "Invalid Boolean value: $val"
    }
}

proc read_options {opt_dir} {
    global options
    array set equiv { }
    foreach opt_file [glob -nocomplain -directory $opt_dir *.option] {
	set option [file tail $opt_file]
	set option [string replace $option end-6 end ""]
	if {! [regexp {^\w+$} $option]} {
	    puts stderr "Invalid option name: $option"
	    exit 1
	}
	set option [string toupper $option]
	set rf [open $opt_file r]
	set build 0
	set syntax {.*}
	set defval ""
	array unset equiv
	foreach ln [split [read $rf] \n] {
	    regsub {^\s+} $ln "" ln
	    regsub {\s+$} $ln "" ln
	    if {$ln eq ""} { continue }
	    if {[regexp {^#} $ln]} { continue }
	    if {$ln eq "positive"} {
		set syntax {[1-9]\d*}
		continue
	    }
	    if {$ln eq "numeric"} {
		set syntax {0|-?[1-9]\d*}
		continue
	    }
	    if {$ln eq "boolean"} {
		set syntax {on|off|yes|no|true|false}
		array set equiv {true on yes on false off no off}
		continue
	    }
	    if {! [regexp {^(\w+)\s*=\s*(\S.*)$} $ln skip key value]} {
		puts stderr "$opt_file: invalid line $ln"
		exit 1
	    }
	    if {$key eq "build"} {
		set_bool build $value
	    } elseif {$key eq "syntax"} {
		set syntax $value
	    } elseif {$key eq "default"} {
		set defval $value
	    } elseif {$key eq "enum"} {
		set lx [split $value ","]
		set syntax [join $lx "|"]
	    } elseif {$key eq "equiv"} {
		set lx [split $value ","]
		if {[llength $lx] < 2} {
		    puts stderr "Invalid equiv, not enough values"
		    exit 1
		}
		set rn [lindex $lx 0]
		for {set i 1} {$i < [llength $lx]} {incr i} {
		    array set equiv [list [lindex $lx $i] $rn]
		}
	    } else {
		puts stderr "$opt_file: invalid key $key"
		exit 1
	    }
	}
	close $rf
	set el [array get equiv]
	array set options [list $option [list $build $syntax $defval $el]]
    }
}

set backends [list]
set sqlite3_versions [list]
array set options { }
read_versions [file join $notfork sqlite3 benchmark versions] "" sqlite3_versions ""
if {[llength $sqlite3_versions] < 1} {
    puts stderr "No SQLite versions specified?"
    exit 1
}
set sqlite3_for_db [lindex $sqlite3_versions 0]

read_options [file join $notfork sqlite3 benchmark]

array set other_values [list \
	BENCHMARK_DB     benchmarks.sqlite \
	BENCHMARK_RUNS   1 \
	NOTFORK_COMMAND  "not-fork" \
	NOTFORK_ONLINE   0 \
	NOTFORK_UPDATE   0 \
	SQLITE_VERSIONS  $sqlite3_for_db \
	USE_SQLITE       "yes" \
]
set options_list [lsort [array names other_values]]
array set other_values [list TARGETS "" ]

foreach backend_dir [glob -nocomplain -directory $notfork *] {
    if [file isdirectory [file join $backend_dir benchmark]] {
	set backend [file tail $backend_dir]
	if {$backend eq "sqlite3"} { continue }
	set BACKEND [string toupper $backend]
	set versions [list]
	set default_version ""
	set ok 0
	set ver_file [file join $backend_dir benchmark versions]
	if {[file exists $ver_file]} {
	    read_versions $ver_file $backend versions default_version
	    set ok 1
	}
	set stand_file [file join $backend_dir benchmark standalone]
	if {[file exists $stand_file]} {
	    read_standalone $stand_file $backend versions
	    set ok 1
	}
	if {! $ok} {
	    puts stderr "No versions defined for $backend"
	    exit 1
	}
	read_options [file join $backend_dir benchmark]
	lappend backends $backend
	lappend backends [list $BACKEND $versions $default_version]
	set bv [list]
	set bs [list]
	foreach v $versions {
	    if {[regexp {^\+.*?-(.*)$} $v skip sv]} {
		lappend bs $sv
	    } elseif {[regexp {^(.*?)\+.*?-(.*$)$} $v skip sv xv]} {
		if {$sv eq $default_version} {
		    lappend bv $xv
		} else {
		    lappend bv $v
		}
	    }
	}
	array set other_values [list \
	    USE_$BACKEND          yes \
	    SQLITE_FOR_$BACKEND   $default_version \
	    ${BACKEND}_VERSIONS   [join $bv] \
	    ${BACKEND}_STANDALONE [join $bs] \
	]
	lappend options_list \
		USE_$BACKEND \
		SQLITE_FOR_$BACKEND \
		${BACKEND}_VERSIONS \
		${BACKEND}_STANDALONE
    }
}
set backends [lsort -stride 2 $backends]

if {$prn} {
    foreach var [array names options] {
	puts $outf "ifneq (\$($var),)"
	puts $outf "BUILD_OPTIONS += -$var='\$($var)'"
	puts $outf "endif"
	puts $outf "ifneq (\$(OPTION_$var),)"
	puts $outf "BUILD_OPTIONS += -$var='\$(OPTION_$var)'"
	puts $outf "endif"
	puts $outf ""
    }
    foreach var $options_list {
	puts $outf "ifneq (\$($var),)"
	puts $outf "BUILD_OPTIONS += $var='\$($var)'"
	puts $outf "endif"
	puts $outf ""
    }
    puts $outf "ifneq (\$(TARGETS),)"
    puts $outf "BUILD_OPTIONS += TARGETS='\$(TARGETS)'"
    puts $outf "endif"
    puts $outf ""
    close $outf
    file rename -force "$outname.tmp" $outname
    exit 0
}

# parse command line to get a list of options

array set option_values { }
foreach {option od} [array get options] {
    array set option_values [list $option [lindex $od 2]]
}

for {set i $argp} {$i < [llength $argv]} {incr i} {
    if {[regexp {^-(\w+)=(.*)$} [lindex $argv $i] skip option value]} {
	set od [array get options $option]
	if {[llength $od] < 2} {
	    puts stderr "Invalid benchmark option $option"
	    exit 1
	}
	set od [lindex $od 1]
	if {! [regexp "^(?:[lindex $od 1])$" $value]} {
	    puts stderr "Invalid value for $option: $value"
	    exit 1
	}
	foreach {e1 e2} [lindex $od 3] {
	    if {$value eq $e1} {
		set value $e2
	    }
	}
	array set option_values [list $option $value]
    } elseif {[regexp {^(\w+)=(.*)$} [lindex $argv $i] skip option value]} {
	set od [array get other_values $option]
	if {[llength $od] < 2} {
	    puts stderr "Invalid option $option"
	    exit 1
	}
	array set other_values [list $option $value]
    } else {
	puts stderr "Invalid option [lindex $argv $i]"
	exit 1
    }
}

# helper array and function to pass "--no-update" to not-fork when
# it makes sense to do so; also "--update" and "--online" if it
# has been requested
array set notfork_updated [list]
set notfork_name $other_values(NOTFORK_COMMAND)

proc notfork_command {target args} {
    global notfork_updated
    global other_values
    global notfork_name
    global notfork
    set rargs [lreverse $args]
    lappend rargs $notfork -i
    if {[array names notfork_updated -exact $target] != ""} {
	lappend rargs "--no-update"
    } else {
	set notfork_updated($target) 1
	if {$other_values(NOTFORK_UPDATE)} {
	    lappend rargs "--update"
	}
    }
    if {$other_values(NOTFORK_ONLINE)} {
	lappend rargs "--online"
    }
    lappend rargs $notfork_name
    lappend rargs -ignorestderr
    set args [lreverse $rargs]
    lappend args $target
    return $args
}

# check not-fork tool can be found and is new enough

set notfork_required "0.3.1"
if {[catch {
    set notfork_found [exec $notfork_name --check-version $notfork_required 2>@1]
} notfork_results notfork_options]} {
    set errorcode [lindex [dict get $notfork_options -errorcode] 0]
    if {$errorcode eq "CHILDSTATUS"} {
	set version_found ""
	if {[regexp {^([\d\.]+)} $notfork_results skip version_found]} {
	    set version_found " ($version_found)"
	}
	puts stderr "Installed version of not-fork$version_found is too old, $notfork_required required"
    } else {
	puts stderr "Cannot run $notfork_name, please check that it is installed and in PATH"
    }
    exit 1
}

set target_string $other_values(TARGETS)
set benchmark_list [list]
set build_list [list]
set build_option_list [list]
set benchmark_to_build [list]
set benchmark_option_list [list]
if {$target_string eq ""} {
    # generate a new list of benchmarks from all the other options
    set benchmark_opts ""
    set benchmark_plus ""
    set benchmark_ol [list]
    set build_opts ""
    set build_plus ""
    set build_ol [list]
    foreach {option value} [lsort -stride 2 [array get option_values]] {
	set od $options($option)
	lappend benchmark_ol $option
	lappend benchmark_ol $value
	if {$value ne [lindex $od 2]} {
	    append benchmark_opts "+[string tolower $option]-$value"
	    set benchmark_plus "+"
	}
	if {[lindex $od 0]} {
	    lappend build_ol $option
	    lappend build_ol $value
	    if {$value ne [lindex $od 2]} {
		append build_opts "+[string tolower $option]-$value"
		set build_plus "+"
	    }
	}
    }
    proc add_target_no {target add_bench} {
	global benchmark_list
	global benchmark_opts
	global benchmark_plus
	global benchmark_option_list
	global benchmark_ol
	global benchmark_to_build
	global build_list
	global build_opts
	global build_plus
	global build_option_list
	global build_ol
	set b "$target$build_plus$build_opts"
	if {$add_bench} {
	    set t "$target$benchmark_plus$benchmark_opts"
	    if {[lsearch -exact $benchmark_list $t] < 0} {
		lappend benchmark_list $t
		lappend benchmark_to_build $b
		lappend benchmark_option_list $benchmark_ol
	    }
	}
	if {[lsearch -exact $build_list $b] < 0} {
	    lappend build_list $b
	    lappend build_option_list $build_ol
	}
    }
    proc add_target_yes {target} {
	global benchmark_list
	global benchmark_opts
	global benchmark_option_list
	global benchmark_ol
	global benchmark_to_build
	global build_list
	global build_opts
	global build_option_list
	global build_ol
	set t "$target$benchmark_opts"
	if {[lsearch -exact $benchmark_list $t] < 0} {
	    lappend benchmark_list $t
	    set b "$target$build_opts"
	    lappend benchmark_to_build $b
	    lappend benchmark_option_list $benchmark_ol
	    if {[lsearch -exact $build_list $b] < 0} {
		lappend build_list $b
		lappend build_option_list $build_ol
	    }
	}
    }
    if {$other_values(USE_SQLITE) eq "yes"} {
	foreach sv [split $other_values(SQLITE_VERSIONS)] {
	    if {$sv ne ""} {
		add_target_no $sv 1
		if {$operation eq "database"} { break }
	    }
	}
    } else {
	# build the first version listed, to update the database,
	# but do not run the corresponding benchmark
	add_target_no [lindex [split $other_values(SQLITE_VERSIONS)] 0] 0
    }
    if {$operation ne "database"} {
	foreach {backend spec} $backends {
	    set BACKEND [lindex $spec 0]
	    if {$other_values(USE_$BACKEND) eq "yes"} {
		set dver $other_values(SQLITE_FOR_$BACKEND)
		set bver $other_values(${BACKEND}_VERSIONS)
		if {$bver eq "all"} {
		    # if a clone needs to happen that may result in
		    # standard output which we don't want; so we call
		    # not-fork twice
		    eval exec [notfork_command $backend -q]
		    set bver [eval exec [notfork_command $backend --list-versions]]
		}
		foreach v [split $bver] {
		    if {[regexp {^(.*?)\+(.*)$} $v skip sv bv]} {
			add_target_no $sv 1
			add_target_yes "$sv+$backend-$bv"
		    } elseif {$v ne ""} {
			add_target_no $dver 1
			add_target_yes "$dver+$backend-$v"
		    }
		}
		set bver $other_values(${BACKEND}_STANDALONE)
		if {$bver eq "all"} {
		    # if a clone needs to happen that may result in
		    # standard output which we don't want; so we call
		    # not-fork twice
		    eval exec [notfork_command $backend -q]
		    set bver [eval exec [notfork_command $backend --list-versions]]
		}
		foreach v [split $bver] {
		    if {[regexp {^(.*?)=(.*)$} $v skip bv sv]} {
			add_target_no $sv 1
			add_target_yes "+$backend-$bv"
		    } elseif {$v ne ""} {
			add_target_yes "+$backend-$v"
		    }
		}
	    }
	}
    }
} else {
    # parse list of benchmarks
    if {$operation eq "database"} {
	puts stderr "Cannot specify explicit targets with \"database\""
	exit 1
    }
    set target_list [split $target_string]
    # make sure we also have an unmodified sqlite3 for the benchmark database
    lappend target_list [lindex [split $other_values(SQLITE_VERSIONS)] 0]
    for {set tptr 0} {$tptr < [llength $target_list]} {incr tptr} {
	set benchmark [lindex $target_list $tptr]
	if {$benchmark eq ""} { continue }
	set benchmark_this [expr $tptr < ([llength $target_list] - 1)]
	set tdata [split $benchmark "+"]
	set sv [lindex $tdata 0]
	set bv [lindex $tdata 1]
	# get a new option array and update it from the targt string
	array set opt_arr [array get option_values]
	foreach optstring [lrange $tdata 2 end] {
	    if {! [regexp {^(\w+)-(.*)$} $optstring skip option value]} {
		puts stderr "Invalid option $optstring"
		exit 1
	    }
	    set od $options([string toupper $option])
	    if {[llength $od] < 2} {
		puts stderr "Invalid option name: $option"
		exit 1
	    }
	    if {$value eq [lindex $od 2]} { continue }
	    if {! [regexp "^(?:[lindex $od 1])$" $value]} {
		puts stderr "Invalid value for $option: $value"
		exit 1
	    }
	    foreach {e1 e2} [lindex $od 3] {
		if {$value eq $e1} {
		    set value $e2
		}
	    }
	    if {$value eq [lindex $od 2]} { continue }
	    set option [string toupper $option]
	    array set opt_arr [list $option $value]
	}
	# now construct a new normalised target string
	set benchmark_opts ""
	set benchmark_plus ""
	set benchmark_ol [list]
	set build_opts ""
	set build_plus ""
	set build_ol [list]
	foreach {option value} [lsort -stride 2 [array get opt_arr]] {
	    set od $options($option)
	    lappend benchmark_ol $option
	    lappend benchmark_ol $value
	    if {$value ne [lindex $od 2]} {
		append benchmark_opts "+[string tolower $option]-$value"
		set benchmark_plus "+"
	    }
	    if {[lindex $od 0]} {
		lappend build_ol $option
		lappend build_ol $value
		if {$value ne [lindex $od 2]} {
		    append build_opts "+[string tolower $option]-$value"
		    set build_plus "+"
		}
	    }
	}
	if {$bv eq ""} {
	    set t "$sv$benchmark_plus$benchmark_opts"
	    set b "$sv$build_plus$build_opts"
	} else {
	    set t "$sv+$bv$benchmark_opts"
	    set b "$sv+$bv$build_opts"
	}
	if {[lsearch -exact $benchmark_list $t] < 0} {
	    if {$benchmark_this} {
		lappend benchmark_list $t
		lappend benchmark_to_build $b
		lappend benchmark_option_list $benchmark_ol
	    }
	    if {[lsearch -exact $build_list $b] < 0} {
		lappend build_list $b
		lappend build_option_list $build_ol
	    }
	}
    }
}

# if they asked "what" we're nearly done

if {$operation eq "what"} {
    foreach option $options_list {
	set value $other_values($option)
	puts "$option=$value"
    }
    foreach {option value} [lsort -stride 2 [array get option_values]] {
	puts "OPTION_$option=$value"
    }
    puts "BUILDS="
    foreach build $build_list {
	puts "    $build"
    }
    puts "TARGETS="
    foreach benchmark $benchmark_list {
	puts "    $benchmark"
    }
    exit 0
}

# now build all necessary targets
# TODO - one day we may have options for building them in parallel

proc write_data {dir name data} {
    set fn [file join $dir $name]
    set fp [open $fn w]
    puts $fp [string trim $data]
    close $fp
}

set build_dir [file normalize $build_dir]

proc run_build {dir prog} {
    set fd [open $prog r]
    set data [read $fd]
    close $fd
    pushd $dir
    eval $data
    popd
}

for {set i 0} {$i < [llength $build_list]} {incr i} {
    set build [lindex $build_list $i]
    set dest_dir [file join $build_dir $build]
    if {[file isdirectory $dest_dir]} { continue }
    set build_optlist [lindex $build_option_list $i]
    set tl [split $build "+"]
    set sqlite3_version [lindex $tl 0]
    if {[llength $tl] < 2} {
	set backend_name ""
	set backend_version ""
    } elseif {! [regexp {^(\w+)-(.*)$} [lindex $tl 1] skip backend_name backend_version]} {
	set backend_name ""
	set backend_version ""
    }
    puts "*** Building $build"
    if {$sqlite3_version ne ""} {
	puts "    SQLITE3_VERSION = $sqlite3_version"
    }
    if {$backend_version ne ""} {
	puts "    BACKEND_NAME = $backend_name"
	puts "    BACKEND_VERSION = $backend_version"
    }
    array set build_options [list]
    foreach {option value} $build_optlist {
	puts "    $option = $value"
	array set env [list "OPTION_$option" $value]
	array set build_options [list $option $value]
    }
    set dest_tmp [file join $build_dir ".$build.tmp"]
    file delete -force $dest_tmp
    file mkdir $dest_tmp
    set sources [file join $dest_tmp sources]
    set lumo_dir [file join $dest_tmp lumo]
    file mkdir $lumo_dir
    set sqlite3_commit_id ""
    if {$sqlite3_version ne ""} {
	puts "    *** Getting sources: sqlite3 $sqlite3_version"
	set pid [eval exec [notfork_command sqlite3 -o $sources -v $sqlite3_version] &]
	set ws [wait $pid]
	if {[lindex $ws 1] ne "EXIT"} { return -code error }
	set sqlite3_info [eval exec [notfork_command sqlite3 -q -v $sqlite3_version]]
	regexp {***:(?n)^commit_id\s*=\s*(\S.*)$} $sqlite3_info skip sqlite3_commit_id
    } else {
	set sqlite3_info [list]
    }
    set backend_commit_id ""
    if {$backend_version ne ""} {
	puts "    *** Getting sources: $backend_name $backend_version"
	set backend_id " $backend_name $backend_version"
	if {$backend_commit_id ne ""} { append backend_id " $backend_commit_id" }
	set pid [eval exec [notfork_command $backend_name -o $sources -v $backend_version] &]
	set ws [wait $pid]
	if {[lindex $ws 1] ne "EXIT"} { return -code error }
	set backend_info [eval exec [notfork_command $backend_name -q -v $backend_version]]
	regexp {***:(?n)^commit_id\s*=\s*(\S.*)$} $backend_info skip backend_commit_id
    } else {
	set backend_info [list]
	set backend_id ""
    }
    array set env [list \
	BACKEND_ID $backend_id \
	BACKEND_COMMIT_ID $backend_commit_id \
	LUMO_BACKEND_NAME $backend_name \
	LUMO_BACKEND_VERSION $backend_version \
	LUMO_BUILD $dest_tmp \
	LUMO_SOURCES $sources \
	MAKEFLAGS "" \
	SQLITE3_COMMIT_ID $sqlite3_commit_id \
	SQLITE3_VERSION $sqlite3_version \
    ]
    if {$backend_version ne ""} {
	puts "    *** Building backend: $backend_name $backend_version"
	set backend_dir [file join $sources $backend_name]
	run_build $backend_dir [file join $backend_dir .lumosql lumo.build]
    }
    if {$sqlite3_version ne ""} {
	puts "    *** Building: sqlite3 $sqlite3_version"
	set sqlite3_dir [file join $sources sqlite3]
	run_build $sqlite3_dir [file join $sqlite3_dir .lumosql lumo.build]
    }
    # if we got here without error, the thing is built
    write_data $lumo_dir "sqlite3_info" $sqlite3_info
    write_data $lumo_dir "sqlite3_commit_id" $sqlite3_commit_id
    write_data $lumo_dir "sqlite3_version" $sqlite3_version
    write_data $lumo_dir "backend_info" $backend_info
    write_data $lumo_dir "backend_commit_id" $backend_commit_id
    write_data $lumo_dir "backend_name" $backend_name
    write_data $lumo_dir "backend_version" $backend_version
    set exe [file join $dest_tmp sqlite3]
    set libs [file join $dest_dir lumo build]
    set fd [open $exe w]
    puts $fd "#!/bin/sh"
    puts $fd "if \[ -n \"\$LD_LIBRARY_PATH\" \]"
    puts $fd "then"
    puts $fd "    LD_LIBRARY_PATH='$libs':\"\$LD_LIBRARY_PATH\""
    puts $fd "else"
    puts $fd "    LD_LIBRARY_PATH='$libs'"
    puts $fd "fi"
    puts $fd "export LD_LIBRARY_PATH"
    puts $fd "exec '$libs/sqlite3' \"\$@\""
    close $fd
    catch { chmod a+rx $exe }
    # build will have copied files of interest to lumo/ so...
    file delete -force $sources
    file rename $dest_tmp $dest_dir
}

if {$operation eq "build"} { exit 0 }

# if the database exists, check it has the correct schema;
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

set sqlite3_for_db [file join $build_dir $sqlite3_for_db sqlite3]

if {[file exists $database_name]} {
    # TODO get table schemas and check them
} else {
    puts "Creating database $database_name"
    flush stdout
    set sqlfd [open "| $sqlite3_for_db $database_name" w]
    puts $sqlfd $run_schema
    puts $sqlfd $test_schema
    close $sqlfd
}

if {$operation ne "benchmark"} { exit 0 }

# and finally run benchmarks

set repeat $other_values(BENCHMARK_RUNS)

proc update_run {run_id data} {
    global sqlite3_for_db
    global database_name
    set sqlfd [open "| $sqlite3_for_db $database_name" w]
    foreach {key value} $data {
	puts $sqlfd "INSERT INTO run_data (run_id, key, value) VALUES ('$run_id', '$key', '$value');"
    }
    close $sqlfd
}

proc update_test {run_id test_number data} {
    global sqlite3_for_db
    global database_name
    set sqlfd [open "| $sqlite3_for_db $database_name" w]
    foreach {key value} $data {
	puts $sqlfd "INSERT INTO test_data (run_id, test_number, key, value) VALUES ('$run_id', $test_number, '$key', '$value');"
    }
    close $sqlfd
}

proc read_data {dir name} {
    set fd [open [file join $dir $name] r]
    set data [read $fd]
    close $fd
    return [lindex [split $data \n] 0]
}

# see what tests we have
set tests [list]
foreach test_file [lsort [glob -directory [file join $notfork sqlite3 benchmark] *.test]] {
    set fd [open $test_file r]
    lappend tests [read $fd]
    close $fd
}
set before_test ""
if {[file exists [file join $notfork sqlite3 benchmark before-test]]} {
    set fd [open [file join $notfork sqlite3 benchmark before-test] r]
    set before_test [read $fd]
    close $fd
}
set after_test ""
if {[file exists [file join $notfork sqlite3 benchmark after-test]]} {
    set fd [open [file join $notfork sqlite3 benchmark after-test] r]
    set after_test [read $fd]
    close $fd
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

set notforking_id "NOT KNOWN"
pushd $notfork
catch {
    set notforking_tmp [exec fossil info]
    regexp {***:(?n)^checkout\s*:\s*(\S+)} $notforking_tmp skip notforking_id
}
popd

array set benchmark_options { }
for {set i 0} {$i < [llength $benchmark_list]} {incr i} {
    set benchmark [lindex $benchmark_list $i]
    set benchmark_optlist [lindex $benchmark_option_list $i]
    puts "*** Running benchmark $benchmark"
    set build [lindex $benchmark_to_build $i]
    set tl [split $build "+"]
    set sqlite3_version [lindex $tl 0]
    if {[llength $tl] < 2} {
	set backend_name ""
	set backend_version ""
    } elseif {! [regexp {^(\w+)-(.*)$} [lindex $tl 1] skip backend_name backend_version]} {
	set backend_name ""
	set backend_version ""
    }
    if {$sqlite3_version eq ""} {
	set title ""
	set with ""
    } else {
	set title "sqlite $sqlite3_version"
	set with " with "
    }
    if {$backend_name ne ""} {
	append title "$with$backend_name $backend_version"
    }
    puts "    TITLE = $title"
    set dest_dir [file join $build_dir $build]
    if {! [file isdirectory $dest_dir]} {
	puts stderr "Build system error: target $build was not built?"
	exit 1
    }
    set lumo_dir [file join $dest_dir lumo]
    set sqlite3_commit_id [read_data $lumo_dir "sqlite3_commit_id"]
    set backend_commit_id [read_data $lumo_dir "backend_commit_id"]
    set sqlite3_to_test [file join $dest_dir sqlite3]
    set sqlite3_name [exec $sqlite3_to_test -version]
    puts "    SQLITE_ID = $sqlite3_commit_id"
    puts "    SQLITE_NAME = $sqlite3_name"
    if {$backend_name ne ""} {
	puts "    BACKEND_ID = $backend_commit_id"
    }
    array unset benchmark_options
    array set benchmark_options $benchmark_optlist
    foreach {option value} $benchmark_optlist {
	puts "    $option = $value"
    }
    if {$repeat < 1} {
	set repeat 1
	set space "    "
    } else {
	set space "        "
    }
    set temp_db_dir [file join $dest_dir tests]
    if {[file isdirectory $temp_db_dir]} {
	file delete -force $temp_db_dir
    }
    set temp_db_name [file join $temp_db_dir db]
    set temp_sql_file [file join $temp_db_dir sql]
    for {set r 1} {$r <= $repeat} {incr r} {
	if {$repeat > 1} {
	    puts "    *** Run $r / $repeat"
	    set space "        "
	} else {
	    set space "    "
	}
	# create a directory for the temp database - the first test is
	# expected to create the database the way it wants it
	file mkdir $temp_db_dir
	set when_run [clock seconds]
	set run_id [exec $sqlite3_for_db $database_name \
	    "select hex(sha3('$benchmark' || randomblob(16) || '$when_run'));"]
	puts "${space}RUN_ID = $run_id"
	update_run $run_id [list \
	    "when-run"        $when_run \
	    "sqlite-version"  $sqlite3_version \
	    "sqlite-id"       $sqlite3_commit_id \
	    "target"          $benchmark \
	    "title"           $title \
	    "sqlite-name"     $sqlite3_name \
	    "notforking-id"   $notforking_id \
	]
	foreach {option value} $benchmark_optlist {
	    update_run $run_id [list "option-[string tolower $option]" $value]
	}
	if {$backend_name ne ""} {
	    update_run $run_id [list \
		"backend-name"     $backend_name \
		"backend-version"  $backend_version \
		"backend"          $backend_name-$backend_version \
		"backend-id"       $backend_commit_id \
	    ]
	}
	set tests_ok 0
	set tests_fail 0
	set tests_intr 0
	set total_time 0
	for {set test_number 1} {$test_number <= [llength $tests]} {incr test_number} {
	    set test_name ""
	    set before_sql ""
	    set test_sql ""
	    set after_sql ""
	    set test_tcl "$before_test [lindex $tests [expr $test_number - 1]] $after_test"
	    apply \
		[list {} "\
		    upvar benchmark_options options \
			  test_name name \
			  before_sql before_sql \
			  test_sql sql \
			  after_sql after_sql
		    $test_tcl"]
	    set sqlfd [open $temp_sql_file w]
	    puts $sqlfd $before_sql
	    close $sqlfd
	    exec $sqlite3_to_test $temp_db_name < $temp_sql_file > /dev/null
	    set sqlfd [open $temp_sql_file w]
	    puts $sqlfd $test_sql
	    close $sqlfd
	    set delay 1000
	    exec sync; after $delay;
	    set status "?"
	    set oct [times]
	    set owt [clock microseconds]
	    if {[catch {
		exec $sqlite3_to_test $temp_db_name < $temp_sql_file > /dev/null
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
	    set sqlfd [open $temp_sql_file w]
	    puts $sqlfd $after_sql
	    close $sqlfd
	    exec $sqlite3_to_test $temp_db_name < $temp_sql_file > /dev/null
	    update_test $run_id $test_number [list \
		"test-name"        $test_name \
		"real-time"        $wt \
		"user-cpu-time"    $ut \
		"system-cpu-time"  $st \
		"status"           $status \
	    ]
	    set total_time [expr $total_time + $wt]
	    puts [format "%s%8s %9.3f %3d %s" $space $status $wt $test_number $test_name]
	}
	set end_run [clock seconds]
	update_run $run_id [list \
	    "end-run"         $end_run \
	    "tests-ok"        $tests_ok \
	    "tests-intr"      $tests_intr \
	    "tests-fail"      $tests_fail \
	]
	puts [format "%s        %10.3f (total time)" $space $total_time]
	# delete temp database
	file delete -force $temp_db_dir
    }
}

# all done

exit 0

