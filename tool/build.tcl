#!/usr/bin/tclsh

# TODO replace "system" with something which checks status

# LumoSQL build and benchmark

# Copyright 2021 The LumoSQL Authors, see LICENSES/MIT
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
# ARGUMENTS: [OUTPUT_FILE]
#            create a Makefile fragment so that "make" can accept
#            command-line options corresponding to build options

# OPERATION: database
# ARGUMENTS: BUILD_DIR DATABASE_NAME
#            create database

# OPERATION: what
# ARGUMENTS: BUILD_OPTIONS
#            show what targets/options have been selected based on command-line

# OPERATION: targets
# ARGUMENTS: BUILD_OPTIONS
#            same as "what", but the list of targets are all in one line,
#            for easier copy-paste when trying to run the exact same list
#            in multiple places

# OPERATION: build
# ARGUMENTS: BUILD_DIR BUILD_OPTIONS
#            build LumoSQL, if necessary

# OPERATION: cleanup
# ARGUMENTS: BUILD_DIR BUILD_OPTIONS
#            check cached builds, and deletes anything which is no longer
#            up-to-date (would be rebuilt anyway)

# OPERATION: benchmark
# ARGUMENTS: BUILD_DIR DATABASE_NAME BUILD_OPTIONS
#            run benchmarks (run all tests marked for benchmarking and save timings)

# OPERATION: test
# ARGUMENTS: BUILD_DIR DATABASE_NAME BUILD_OPTIONS
#            run tests (run all tests without saving timings)

package require Tclx 8.0

if {[llength $argv] < 2} {
    puts stderr "Usage: build.tcl OPERATION NOTFORK_CONFIG ARGUMENTS"
    puts stderr "See documentation for more information"
    exit 1
}

set operation [lindex $argv 0]
set notfork_dir [lindex $argv 1]
set prn 0

if {$operation eq "options"} {
    if {[llength $argv] == 2} {
	set argp 2
	set outf [dup stdout]
    } elseif {[llength $argv] == 3} {
	set outname [lindex $argv 2]
	set argp 3
	set outf [open "$outname.tmp" w]
    } else {
	puts stderr "Usage: build.tcl options NOTFORK_CONFIG [OUTPUT_FILE]"
	exit 1
    }
    puts $outf "BUILD_OPTIONS :="
    puts $outf ""
    set prn 1
} elseif {$operation eq "database"} {
    if {[llength $argv] < 4} {
	puts stderr "Usage: build.tcl database NOTFORK_CONFIG BUILD_DIR DATABASE_NAME BUILD_OPTIONS..."
	exit 1
    }
    set build_dir [lindex $argv 2]
    set database_name [lindex $argv 3]
    set argp 4
} elseif {$operation eq "what" || $operation eq "targets"} {
    set argp 2
} elseif {$operation eq "build" || $operation eq "cleanup"} {
    if {[llength $argv] < 3} {
	puts stderr "Usage: build.tcl $operation NOTFORK_CONFIG BUILD_DIR BUILD_OPTIONS..."
	exit 1
    }
    set build_dir [lindex $argv 2]
    set argp 3
} elseif {$operation eq "test" || $operation eq "benchmark"} {
    if {[llength $argv] < 4} {
	puts stderr "Usage: build.tcl $operation NOTFORK_CONFIG BUILD_DIR DATABASE_NAME BUILD_OPTIONS..."
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

if {! [file isdirectory $notfork_dir]} {
    puts stderr "Configuration directory $notfork_dir not found"
    exit 1
}

proc read_versions {ver_file backend vname dname} {
    set rf [open $ver_file r]
    upvar $vname vlist
    if {$dname ne ""} { upvar $dname deflist }
    foreach ln [split [read $rf] \n] {
	regsub {^\s+} $ln "" ln
	regsub {\s+$} $ln "" ln
	if {$ln eq ""} { continue }
	if {[regexp {^#} $ln]} { continue }
	if {$backend eq ""} {
	    set target [list $ln]
	} elseif { [regexp {^=\s*(.*)$} $ln skip v] } {
	    lappend deflist $v
	    continue
	} else {
	    set lx [split $ln "+"]
	    if {[llength $lx] < 2} {
		set sqlite3_versions $deflist
		set backend_version $ln
	    } else {
		set sqlite3_versions [list [lindex $lx 0]]
		set backend_version [lindex $lx 1]
	    }
	    set target [list]
	    foreach v $sqlite3_versions {
		lappend target "$v+$backend-$backend_version"
	    }
	}
	foreach t $target {
	    if {[lsearch -exact $vlist $t] < 0} {
		lappend vlist $t
	    }
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
	set requiv [list]
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
		for {set eqnum 1} {$eqnum < [llength $lx]} {incr eqnum} {
		    array set equiv [list [lindex $lx $eqnum] $rn]
		}
	    } elseif {$key eq "requiv"} {
		regsub -all {\s+} $value " " value
		set lx [split $value " "]
		if {[llength $lx] != 2} {
		    puts stderr "Invalid requiv, it needs 2 values"
		    exit 1
		}
		lappend requiv [lindex $lx 0] [lindex $lx 1]
	    } else {
		puts stderr "$opt_file: invalid key $key"
		exit 1
	    }
	}
	close $rf
	set el [array get equiv]
	array set options [list $option [list $build $syntax $defval $el $requiv]]
    }
}

set backends [list]
array set options { }
set sqlite3_versions [list]
read_versions [file join $notfork_dir sqlite3 benchmark versions] "" sqlite3_versions ""
if {[llength $sqlite3_versions] < 1} {
    puts stderr "No SQLite versions specified?"
    exit 1
}

read_options [file join $notfork_dir sqlite3 benchmark]

array set other_values [list \
	ALWAYS_REBUILD   0 \
	BENCHMARK_RUNS   1 \
	CACHE_DIR        "" \
	COPY_DATABASES   "" \
	COPY_SQL         "" \
	CPU_COMMENT      "" \
	DB_DIR           "" \
	DEBUG_BUILD      0 \
	DISK_COMMENT     "" \
	EXTRA_BUILDS     "" \
	KEEP_SOURCES     0 \
	LUMO_TEST_DIR    "" \
	MAKE_COMMAND     "make" \
	NOTFORK_COMMAND  "not-fork" \
	NOTFORK_MIRROR   "" \
	NOTFORK_ONLINE   0 \
	NOTFORK_UPDATE   0 \
	SQLITE_FOR_DB    "" \
	SQLITE_VERSIONS  [join $sqlite3_versions] \
	USE_SQLITE       "yes" \
]
set options_list [lsort [array names other_values]]
array set other_values [list TARGETS "" ]

foreach backend_dir [glob -nocomplain -directory $notfork_dir *] {
    if [file isdirectory [file join $backend_dir benchmark]] {
	set backend [file tail $backend_dir]
	if {$backend eq "sqlite3"} { continue }
	set BACKEND [string toupper $backend]
	set versions [list]
	set default_versions [list]
	set ok 0
	set ver_file [file join $backend_dir benchmark versions]
	if {[file exists $ver_file]} {
	    read_versions $ver_file $backend versions default_versions
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
	lappend backends [list $BACKEND $versions $default_versions]
	set bv [list]
	set bs [list]
	foreach v $versions {
	    if {[regexp {^\+.*?-(.*)$} $v skip sv]} {
		if {[lsearch -exact $bs $sv] < 0} {
		    lappend bs $sv
		}
	    } elseif {[regexp {^(.*?)\+.*?-(.*$)$} $v skip sv xv]} {
		if {[lsearch -exact $default_versions $sv] < 0} {
		    set xv $v
		}
		if {[lsearch -exact $bv $xv] < 0} {
		    lappend bv $xv
		}
	    }
	}
	array set other_values [list \
	    USE_$BACKEND          yes \
	    SQLITE_FOR_$BACKEND   [join $default_versions] \
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
    if {[llength $argv] > 2} { file rename -force "$outname.tmp" $outname }
    exit 0
}

# parse command line to get a list of options

array set option_values { }
set default_options [list]
foreach {option od} [array get options] {
    set value [lindex $od 2]
    array set option_values [list $option $value]
    if {[lindex $od 0]} {
	lappend default_options $option
	lappend default_options $value
    }
}

for {set anum $argp} {$anum < [llength $argv]} {incr anum} {
    if {[regexp {^-(\w+)=(.*)$} [lindex $argv $anum] skip option value]} {
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
	foreach {re s} [lindex $od 4] {
	    regsub "^(?:$re)$" $value $s value
	}
	array set option_values [list $option $value]
    } elseif {[regexp {^(\w+)=(.*)$} [lindex $argv $anum] skip option value]} {
	set od [array get other_values $option]
	if {[llength $od] < 2} {
	    puts stderr "Invalid option $option"
	    exit 1
	}
	array set other_values [list $option $value]
    } else {
	puts stderr "Invalid option [lindex $argv $anum]"
	exit 1
    }
}

# helper array and function to pass "--no-update" to not-fork when
# it makes sense to do so; also "--update" and "--online" if it
# has been requested
array set notfork_updated [list]
set notfork_name $other_values(NOTFORK_COMMAND)
set make_command $other_values(MAKE_COMMAND)

# not-fork version 0.4.1 is required for --use-version which we need
set notfork_required "0.4.1"
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

# not-fork 1.0 may introduce incompatible changes and we don't want that, so
# we ask it to confirm that it can find a version older than that
set notfork_maximum "0.999"
# and we'll need 0.5 to take advantage of the new methods it introduced
# (append and fragment_patch)
set notfork_minimum "0.5"
# see if it knows how to find a suitable version
exec $notfork_name --quiet --find-version "$notfork_minimum:$notfork_maximum"

# from now on, not-fork will be called with --use-version

proc notfork_command {target args} {
    global notfork_updated
    global other_values
    global notfork_name
    global notfork_dir
    global notfork_minimum
    global notfork_maximum
    set rargs [lreverse $args]
    lappend rargs $notfork_dir -i
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
    if {$other_values(NOTFORK_MIRROR) ne ""} {
	lappend rargs $other_values(NOTFORK_MIRROR) "--local-mirror"
    }
    if {$other_values(CACHE_DIR) ne ""} {
	lappend rargs $other_values(CACHE_DIR) "--cache"
    }
    lappend rargs "$notfork_minimum:$notfork_maximum" --use-version
    lappend rargs $notfork_name
    lappend rargs -ignorestderr
    set args [lreverse $rargs]
    lappend args $target
    return $args
}

proc versions_list {result backend names slist} {
    upvar $result R
    set R [list]
    foreach name [split $names] {
	if {$name eq ""} { continue }
	if {$slist ne ""} {
	    if {[regexp {^(.+)\+(.+)$} $name skip sv name]} {
		# recursion: see recursion
		versions_list S sqlite3 $sv ""
	    } else {
		set S $slist
	    }
	} else {
	    set S [list ""]
	}
	set all 0
	set minver ""
	set maxver ""
	set remove 0
	if {[string index $name 0] eq "-"} {
	    set remove 1
	    set name [string range $name 1 end]
	}
	if {$name eq "all"} {
	    set all 1
	} elseif {[string index $name end] eq "+"} {
	    set all 1
	    set minver [string range $name 0 end-1]
	} elseif {[regexp {^(.*)-$} $name skip ver]} {
	    set all 1
	    set maxver [string range $name 0 end-1]
	}
	if {$all || $name eq "latest"} {
	    # if a clone needs to happen that may result in standard output
	    # which we don't want; so we call not-fork twice
	    eval exec [notfork_command $backend -q]
	    set bvers [split [eval exec [notfork_command $backend --version-range "$minver:$maxver"]]]
	    if {[llength $bvers] < 1} { continue }
	    if {! $all} {
		set bvers [lrange $bvers end end]
	    }
	} else {
	    set bvers [list $name]
	}
	foreach bv $bvers {
	    foreach sv $S {
		if {$sv eq ""} {
		    set tgt $bv
		} else {
		    set tgt "$sv+$backend-$bv"
		}
		set pos [lsearch -exact $R $tgt]
		if {$pos < 0 && ! $remove} {
		    lappend R $tgt
		} elseif {$pos >= 0 && $remove} {
		    set R [lreplace $R $pos $pos]
		}
	    }
	}
    }
}

if {$operation ne "what" && $operation ne "targets"} {
    set build_dir [file normalize $build_dir]
}

if {$other_values(SQLITE_FOR_DB) eq ""} {
    versions_list sqlite3_for_db sqlite3 latest ""
    set sqlite3_for_db [lindex $sqlite3_for_db 0]
} else {
    set sqlite3_for_db $other_values(SQLITE_FOR_DB)
}
set target_string $other_values(TARGETS)
set benchmark_list [list]
set build_list [list $sqlite3_for_db]
set build_option_list [list $default_options]
set benchmark_to_build [list]
set benchmark_option_list [list]
set expanded_targets [list]
set expanded_extra [list]
if {$operation ne "database"} {
    # see if we want to generate a target string from other options,,,
    if {$target_string eq "" && $operation ne "cleanup"} {
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
	    versions_list svers sqlite3 $other_values(SQLITE_VERSIONS) ""
	    foreach sv $svers {
		add_target_no $sv 1
	    }
	}
	foreach {backend spec} $backends {
	    set BACKEND [lindex $spec 0]
	    if {$other_values(USE_$BACKEND) eq "yes"} {
		versions_list dvers sqlite3 $other_values(SQLITE_FOR_$BACKEND) ""
		versions_list bvers $backend $other_values(${BACKEND}_VERSIONS) $dvers
		foreach bver $bvers {
		    if {[regexp {^(.*?)\+(.*)$} $bver skip sv bv]} {
			add_target_no $sv 1
			add_target_yes $bver
		    }
		}
		versions_list svers $backend $other_values(${BACKEND}_STANDALONE) ""
		foreach sver $svers {
		    if {[regexp {^(.*?)=(.*)$} $sver skip bv sv]} {
			add_target_no $sv 1
			add_target_yes "+$backend-$bv"
		    } else {
			add_target_yes "+$backend-$v"
		    }
		}
	    }
	}
	set target_string ""
	# we continue with any extra builds which might have been requested
    }
    set target_list [list]
    if {$operation eq "cleanup"} {
	# targets to check are existing builds
	set build_list [list]
	foreach fn [glob -directory $build_dir -nocomplain *] {
	    lappend target_list [lindex [file split $fn] end]
	}
	if {[llength $target_list] == 0} { exit 0 }
    } else {
	if {$target_string ne ""} {
	    foreach tname [split [string map {: :c "\\ " :s} $target_string]] {
		if {$tname ne ""} {
		    lappend target_list [string map {:c : :s " "} $tname]
		}
	    }
	}
	if {$other_values(EXTRA_BUILDS) ne ""} {
	    foreach tname [split [string map {: :c "\\ " :s} $other_values(EXTRA_BUILDS)]] {
		if {$tname ne ""} {
		    lappend target_list " [string map {:c : :s " "} $tname]"
		}
	    }
	}
    }
    for {set tptr 0} {$tptr < [llength $target_list]} {incr tptr} {
	set benchmark [lindex $target_list $tptr]
	if {$benchmark eq ""} { continue }
	set do_benchmark 1
	if {[string range $benchmark 0 0] eq " "} {
	    set do_benchmark 0
	    set benchmark [string range $benchmark 1 end]
	}
	# allow some special syntax to help running alternative tests... this
	# is not recommended for TARGETS because it results in non-repeatable
	# lists, but we can use that with "make targets" to convert a target
	# of the type "3.35.0\++lmdb-all" into a constant (long) list
	set tdata [list]
	foreach titem [split [string map {: :c \\+ :p} $benchmark] "+"] {
	    lappend tdata [string map {:p + :c :} $titem]
	}
	if {[llength $tdata] < 1} {continue}
	versions_list svlist sqlite3 [lindex $tdata 0] ""
	set bvlist [list ""]
	if {[llength $tdata] > 1} {
	    set bv [lindex $tdata 1]
	    if {$bv ne ""} {
		set failed 1
		if {[regexp {^(\w+)-(.*)$} $bv skip bname bversion]} {
		    if {[file isdirectory [file join $notfork_dir $bname benchmark]]} {
			versions_list bxlist $bname $bversion ""
			if {[llength $bxlist] > 0} {
			    set bvlist [list]
			    foreach bv $bxlist {
				lappend bvlist "$bname-$bv"
			    }
			    set failed 0
			}
		    }
		}
		if {$failed} {
		    puts stderr "Invalid target ($benchmark), backend needs to be NAME-VERSION"
		    exit 2
		}
	    }
	}
	foreach sv $svlist {
	    foreach bv $bvlist {
		# get a new option array and update it from the targt string
		array set opt_arr [array get option_values]
		foreach optstring [lrange $tdata 2 end] {
		    if {! [regexp {^(\w+)-(.*)$} $optstring skip option value]} {
			puts stderr "Invalid option $optstring"
			exit 1
		    }
		    if {[llength [array names options -exact [string toupper $option]]] == 0} {
			puts stderr "Invalid option name: $option"
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
		    foreach {re s} [lindex $od 4] {
			regsub "^(?:$re)$" $value $s value
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
		if {$do_benchmark && [lsearch -exact $benchmark_list $t] < 0} {
		    lappend benchmark_list $t
		    lappend benchmark_to_build $b
		    lappend benchmark_option_list $benchmark_ol
		}
		if {[lsearch -exact $build_list $b] < 0} {
		    lappend build_list $b
		    lappend build_option_list $build_ol
		}
		if {$do_benchmark} {
		    lappend expanded_targets $t
		} else {
		    lappend expanded_extra $b
		}
	    }
	}
    }
}

# if they asked "what" we're nearly done

if {$operation eq "what" || $operation eq "targets"} {
    foreach option $options_list {
	set value $other_values($option)
	puts "$option=$value"
    }
    foreach {option value} [lsort -stride 2 [array get option_values]] {
	puts "OPTION_$option=$value"
    }
    puts "BUILDS="
    if {$operation eq "what"} {
	foreach build $build_list {
	    puts "    $build"
	}
    } else {
	puts "    [join $build_list]"
    }
    puts "TARGETS="
    if {$operation eq "what"} {
	foreach benchmark $benchmark_list {
	    puts "    $benchmark"
	}
    } else {
	puts "    [join $benchmark_list]"
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

proc run_build {dir prog} {
    set fd [open $prog r]
    set data [read $fd]
    close $fd
    pushd $dir
    eval $data
    popd
}

proc search_dir {subdir exclude} {
    global dest_dir
    global mtime
    global skip_rebuild
    global notfork_dir
    global notfork_copy
    set rootdir [file join $notfork_dir $subdir]
    if {[file isdirectory $rootdir]} {
	foreach fn [glob -directory $rootdir -nocomplain *] {
	    set bn [lindex [file split $fn] end]
	    if {[lsearch -exact $exclude $bn] < 0} {
		set subfile [file join $subdir $bn]
		if {[file isdirectory $fn]} {
		    search_dir $subfile [list]
		    if {! $skip_rebuild} {return}
		} else {
		    set dmtime [file mtime $fn]
		    if {$mtime < $dmtime} {
			set clear_rebuild 1
			catch {
			    set f [open $fn r]
			    set d1 [read $f]
			    close $f
			    set f [open [file join $notfork_copy $subdir $bn] r]
			    set d2 [read $f]
			    close $f
			    if {$d1 eq $d2} {
				if {$skip_rebuild < $dmtime} {
				    set skip_rebuild $dmtime
				}
				set clear_rebuild 0
			    }
			}
			if {$clear_rebuild} {
			    set skip_rebuild 0
			    return
			}
		    }
		}
	    }
	}
    }
}

proc check_mtime {subdir} {
    search_dir $subdir [list benchmark]
}

set wd [open .build.info w]
puts $wd $build_dir
puts $wd $sqlite3_for_db
close $wd

set lock_dir [file join $build_dir .build_lock]
file mkdir $lock_dir
set num_builds [llength $build_list]
set build_todo [list]
for {set bnum 0} {$bnum < [llength $build_list]} {incr bnum} {
    lappend build_todo [expr {$bnum + 1}]
    lappend build_todo [lindex $build_list $bnum]
}

if {$operation eq "cleanup"} {
    set skipping "Keeping"
    set rebuilding "Cleaning up"
} else {
    set skipping "Skipping"
    set rebuilding "Rebuilding"
}

set num_skipped 0
while {[llength $build_todo] > 0} {
    set bnum [lindex $build_todo 0]
    set build [lindex $build_todo 1]
    set build_todo [lrange $build_todo 2 end]
    # we need a lockfile outside the actual build directory - because we
    # may need to acquire the lock before creating it
    set lock_file [file join $lock_dir $build]
    set lock_id [open $lock_file a]
    # in theory, if the directory already exists we may be able to decide
    # not to rebuild anyway, but this is simpler code at the cost of
    # a few nanoseconds in case of collision
    if {! [flock -write -nowait $lock_id]} {
	if {[llength $build_todo] > $num_skipped} {
	    puts "*** Skipping locked $build $bnum/$num_builds"
	    close $lock_id
	    if {! $other_values(DEBUG_BUILD) && $operation ne "cleanup"} {
		lappend build_todo $bnum
		lappend build_todo $build
		incr num_skipped
	    }
	    continue
	}
	# we skipped everything since last build, wait on this lock
	puts "*** Waiting for lock on $build"
	flock -write $lock_id
    }
    set num_skipped 0
    set dest_dir [file join $build_dir $build]
    set build_optlist [lindex $build_option_list [expr $bnum - 1]]
    set tl [split $build "+"]
    set sqlite3_version [lindex $tl 0]
    if {[llength $tl] < 2} {
	set backend_name ""
	set backend_version ""
    } elseif {! [regexp {^(\w+)-(.*)$} [lindex $tl 1] skip backend_name backend_version]} {
	set backend_name ""
	set backend_version ""
    }
    set notfork_copy [file join $dest_dir notfork_copy]
    set ts_file [file join $dest_dir build_time]
    if {[file isdirectory $dest_dir]} {
	# check if the build is at least as recent as our files
	if {[file exists $ts_file] && ! $other_values(ALWAYS_REBUILD)} {
	    set rd [open $ts_file]
	    set mtime [read -nonewline $rd]
	    close $rd
	    set skip_rebuild 0
	    # force rebuild if timestamp files are missing
	    if {[file exists [file join $dest_dir lumo sqlite3_commit_timestamp]]} {
		if {[regexp {^\d+$} $mtime]} {
		    set skip_rebuild $mtime
		}
		if {$skip_rebuild} {
		    if {$sqlite3_version ne ""} {
			check_mtime sqlite3
		    }
		    if {$backend_version ne ""} {
			check_mtime $backend_name
		    }
		}
		if {$skip_rebuild} {
		    if {$skip_rebuild > $mtime} {
			set f [open $ts_file w]
			puts $f $skip_rebuild
			close $f
		    }
		    funlock $lock_id
		    close $lock_id
		    if {$other_values(DEBUG_BUILD)} {
			puts "*** $skipping up-to-date $build $bnum/$num_builds"
		    }
		    continue
		}
	    }
	}
	if {! $other_values(DEBUG_BUILD)} { file delete -force $dest_dir }
	puts "*** [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"] $rebuilding $build (sources changed) $bnum/$num_builds"
	if {$operation eq "cleanup"} {
	    funlock $lock_id
	    close $lock_id
	    # we leave the lock file, it's zero-length and if we delete it now
	    # there is a risk that another process is now waiting on the lock
	    # to start a rebuild, it continues with a lock on a deleted file,
	    # and then a third process creates a new lock file and starts the
	    # same rebuild concurrently; there may be a clever way to delete
	    # it without causing race condition but we don't know what that is
	    continue
	}
    } else {
	puts "*** [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"] Building $build $bnum/$num_builds"
    }
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
    if {$other_values(DEBUG_BUILD)} { continue }
    file mkdir $dest_dir
    # get the "build time" from the filesystem's own clock by...
    file stat $dest_dir build_stat
    set build_time $build_stat(mtime)
    set sources [file join $dest_dir sources]
    file copy $notfork_dir $notfork_copy
    set lumo_dir [file join $dest_dir lumo]
    file mkdir $lumo_dir
    set sqlite3_commit_id ""
    set sqlite3_commit_timestamp ""
    if {$sqlite3_version ne ""} {
	puts "    *** Getting sources: sqlite3 $sqlite3_version"
	if {[string range $sqlite3_version 0 6] eq "commit-"} {
	    set vcopt "-c[string range $sqlite3_version 7 end]"
	} else {
	    set vcopt "-v$sqlite3_version"
	}
	set pid [eval exec [notfork_command sqlite3 -o $sources $vcopt] &]
	set ws [wait $pid]
	if {[lindex $ws 1] ne "EXIT"} { return -code error }
	set sqlite3_info [eval exec [notfork_command sqlite3 -q $vcopt]]
	regexp {***:(?n)^commit_id\s*=\s*(\S.*)$} $sqlite3_info skip sqlite3_commit_id
	regexp {***:(?n)^commit_timestamp\s*=\s*(\S.*)$} $sqlite3_info skip sqlite3_commit_timestamp
    } else {
	set sqlite3_info [list]
    }
    set backend_commit_id ""
    set backend_commit_timestamp ""
    if {$backend_version ne ""} {
	puts "    *** Getting sources: $backend_name $backend_version"
	set backend_id "$backend_name $backend_version"
	if {[string range $backend_version 0 6] eq "commit-"} {
	    set vcopt "-c[string range $backend_version 7 end]"
	} else {
	    set vcopt "-v$backend_version"
	}
	set pid [eval exec [notfork_command $backend_name -o $sources $vcopt] &]
	set ws [wait $pid]
	if {[lindex $ws 1] ne "EXIT"} { return -code error }
	set backend_info [eval exec [notfork_command $backend_name -q $vcopt]]
	regexp {***:(?n)^commit_id\s*=\s*(\S.*)$} $backend_info skip backend_commit_id
	regexp {***:(?n)^commit_timestamp\s*=\s*(\S.*)$} $backend_info skip backend_commit_timestamp
    } else {
	set backend_info [list]
	set backend_id ""
    }
    array set env [list \
	BACKEND_ID $backend_id \
	BACKEND_COMMIT_ID $backend_commit_id \
	BACKEND_COMMIT_TIMESTAMP $backend_commit_timestamp \
	LUMO_BACKEND_NAME $backend_name \
	LUMO_BACKEND_VERSION $backend_version \
	LUMO_BUILD $dest_dir \
	LUMO_SOURCES $sources \
	MAKEFLAGS "" \
	SQLITE3_COMMIT_ID $sqlite3_commit_id \
	SQLITE3_COMMIT_TIMESTAMP $sqlite3_commit_timestamp \
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
    write_data $lumo_dir "sqlite3_commit_timestamp" $sqlite3_commit_timestamp
    write_data $lumo_dir "sqlite3_version" $sqlite3_version
    write_data $lumo_dir "backend_info" $backend_info
    write_data $lumo_dir "backend_commit_id" $backend_commit_id
    write_data $lumo_dir "backend_commit_timestamp" $backend_commit_timestamp
    write_data $lumo_dir "backend_name" $backend_name
    write_data $lumo_dir "backend_version" $backend_version
    set exe [file join $dest_dir sqlite3]
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
    # and let's make one to run under a debugger too
    set exe [file join $dest_dir sqlite3.gdb]
    set fd [open $exe w]
    puts $fd "#!/bin/sh"
    puts $fd "if \[ -n \"\$LD_LIBRARY_PATH\" \]"
    puts $fd "then"
    puts $fd "    LD_LIBRARY_PATH='$libs':\"\$LD_LIBRARY_PATH\""
    puts $fd "else"
    puts $fd "    LD_LIBRARY_PATH='$libs'"
    puts $fd "fi"
    puts $fd "export LD_LIBRARY_PATH"
    puts $fd "exec gdb '$libs/sqlite3' \"\$@\""
    close $fd
    catch { chmod a+rx $exe }
    if {! $other_values(KEEP_SOURCES)} { file delete -force $sources }
    set td [open $ts_file w]
    puts $td $build_time
    close $td
    funlock $lock_id
    close $lock_id
}

if {$operation eq "build" || $operation eq "cleanup"} { exit 0 }

set sqlite3_for_db [file join $build_dir $sqlite3_for_db sqlite3]

# if the database exists, check it has the correct schema;
# if it does not exist, create it

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

if {[file exists $database_name]} {
    # TODO get table schemas and check them
} else {
    puts "Creating database $database_name"
    flush stdout
    if {! $other_values(DEBUG_BUILD)} {
	set sqlfd [open "| $sqlite3_for_db $database_name" w]
	puts $sqlfd $run_schema
	puts $sqlfd $test_schema
	close $sqlfd
    }
}

if {$operation ne "benchmark" && $operation ne "test"} { exit 0 }

# and finally run benchmarks

if {$operation eq "test"} {
    set repeat 1
} else {
    set repeat $other_values(BENCHMARK_RUNS)
    if {! $other_values(DEBUG_BUILD)} {
	set wd [open .benchdb.info w]
	puts $wd $database_name
	close $wd
    }
}

proc update_run {run_id data} {
    global sqlite3_for_db
    global database_name
    set sqlfd [open "| $sqlite3_for_db $database_name" w]
    foreach {key value} $data {
	set qvalue [regsub -all {'} $value {''}]
	puts $sqlfd "INSERT INTO run_data (run_id, key, value) VALUES ('$run_id', '$key', '$qvalue');"
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
if {$other_values(LUMO_TEST_DIR) eq ""} {
    set benchmark_dir [file join $notfork_dir sqlite3 benchmark]
} else {
    if {$operation ne "test"} {
	puts stderr "Setting LUMO_TEST_DIR is currently supported only for 'test'"
	exit 1
    }
    set benchmark_dir $other_values(LUMO_TEST_DIR)
}
foreach test_file [lsort [glob -directory $benchmark_dir *.test]] {
    lappend tests [lindex [file split $test_file] end]
    set fd [open $test_file r]
    lappend tests [read $fd]
    close $fd
}
set before_test ""
if {[file exists [file join $benchmark_dir before-test]]} {
    set fd [open [file join $benchmark_dir before-test] r]
    set before_test [read $fd]
    close $fd
}
set after_test ""
if {[file exists [file join $benchmark_dir after-test]]} {
    set fd [open [file join $benchmark_dir after-test] r]
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
set notforking_date "NOT KNOWN"
pushd $notfork_dir
catch {
    set notforking_tmp [exec fossil info]
    regexp {***:(?n)^checkout\s*:\s*(\S+)\s+(\S+)\s+(\S+)} \
	    $notforking_tmp skip notforking_id ndate ntime
    set notforking_date "$ndate $ntime"
}
popd

array set benchmark_options { }
set test_result [list]
for {set bnum 0} {$bnum < [llength $benchmark_list]} {incr bnum} {
    set benchmark [lindex $benchmark_list $bnum]
    set benchmark_optlist [lindex $benchmark_option_list $bnum]
    puts "*** [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"] Running $operation $benchmark [expr {$bnum + 1}]/[llength $benchmark_list]"
    set build [lindex $benchmark_to_build $bnum]
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
    if {! [file isdirectory $dest_dir] && ! $other_values(DEBUG_BUILD)} {
	puts stderr "Build system error: target $build was not built?"
	exit 1
    }
    set lumo_dir [file join $dest_dir lumo]
    set sqlite3_to_test [file join $dest_dir sqlite3]
    if {! $other_values(DEBUG_BUILD)} {
	set sqlite3_name [exec $sqlite3_to_test -version]
	set sqlite3_commit_id [read_data $lumo_dir "sqlite3_commit_id"]
	set sqlite3_commit_timestamp [read_data $lumo_dir "sqlite3_commit_timestamp"]
	set backend_commit_id [read_data $lumo_dir "backend_commit_id"]
	set backend_commit_timestamp [read_data $lumo_dir "backend_commit_timestamp"]
	puts "    SQLITE_ID = $sqlite3_commit_id"
	puts "    SQLITE_TIMESTAMP = $sqlite3_commit_timestamp"
	puts "    SQLITE_NAME = $sqlite3_name"
	if {$backend_name ne ""} {
	    puts "    BACKEND_ID = $backend_commit_id"
	    puts "    BACKEND_TIMESTAMP = $backend_commit_timestamp"
	}
    }
    array unset benchmark_options
    array set benchmark_options $benchmark_optlist
    foreach {option value} $benchmark_optlist {
	puts "    $option = $value"
    }
    if {$other_values(DEBUG_BUILD)} {continue}
    if {[regexp {^(\d+),(\d+)$} $benchmark_options(DATASIZE) skip rs ws]} {
	array set benchmark_options [list DATASIZE_R $rs DATASIZE_W $ws]
    } else {
	set s $benchmark_options(DATASIZE)
	array set benchmark_options [list DATASIZE_R $s DATASIZE_W $s]
    }
    if {$repeat < 1} {
	set repeat 1
	set space "    "
    } else {
	set space "        "
    }
    if {$other_values(DB_DIR) eq ""} {
	set temp_db_dir [file join $dest_dir tests]
    } else {
	set temp_db_dir [file join $other_values(DB_DIR) $build]
    }
    if {[file isdirectory $temp_db_dir]} {
	file delete -force $temp_db_dir
    }
    set temp_db_name [file join $temp_db_dir db]
    set temp_sql_file [file join $temp_db_dir sql]
    set backend_before_test ""
    set backend_after_test ""
    if {$backend_name ne "" && $other_values(LUMO_TEST_DIR) eq ""} {
	set backend_notfork [file join $notfork_dir $backend_name benchmark]
	if {[file exists [file join $backend_notfork before-test]]} {
	    set fd [open [file join $backend_notfork before-test] r]
	    set backend_before_test [read $fd]
	    close $fd
	}
	if {[file exists [file join $backend_notfork after-test]]} {
	    set fd [open [file join $backend_notfork after-test] r]
	    set backend_after_test [read $fd]
	    close $fd
	}
    }
    # before we start... measure the time taken to write and read the disk in $temp_db_dir
    if {$operation eq "benchmark"} {
	file mkdir $temp_db_dir
	set block_data [string range [string repeat "0123456789abcde" 1024] 1 end]
	set delay 1000
	exec sync; after $delay;
	set before [clock microseconds]
	set wrfile [open $temp_db_name w]
	for {set block 0} {$block < 16384} {incr block} {
	    puts $wrfile $block_data
	}
	sync $wrfile
	close $wrfile
	set delay 1000
	exec sync; after $delay;
	set disk_write_time [expr {([clock microseconds] - $before) / 1000000.0}]
	set before [clock microseconds]
	set rdfile [open $temp_db_name r]
	read $rdfile
	close $rdfile
	set disk_read_time [expr {([clock microseconds] - $before) / 1000000.0}]
	file delete $temp_db_name
	puts [format "    DISK_READ_TIME = %.3f" $disk_read_time]
	puts [format "    DISK_WRITE_TIME = %.3f" $disk_write_time]
    }
    for {set r 1} {$r <= $repeat} {incr r} {
	if {$repeat > 1} {
	    puts "    *** [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"] Run $r / $repeat"
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
	    "sqlite-date"     $sqlite3_commit_timestamp \
	    "target"          $benchmark \
	    "title"           $title \
	    "sqlite-name"     $sqlite3_name \
	    "notforking-date" $notforking_date \
	    "notforking-id"   $notforking_id \
	    "disk-comment"    $other_values(DISK_COMMENT) \
	    "cpu-comment"     $other_values(CPU_COMMENT) \
	    "cpu-type"        $tcl_platform(machine) \
	    "os-type"         $tcl_platform(os) \
	    "os-version"      $tcl_platform(osVersion) \
	    "byte-order"      $tcl_platform(byteOrder) \
	    "word-size"       $tcl_platform(wordSize) \
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
		"backend-date"     $backend_commit_timestamp \
	    ]
	}
	if {$operation eq "benchmark"} {
	    update_run $run_id [list \
		"disk-read-time"  $disk_read_time \
		"disk-write-time" $disk_write_time \
	    ]
	}
	set tests_ok 0
	set tests_fail 0
	set tests_intr 0
	set total_time 0
	set test_number 0
	foreach {test_file test_data} $tests {
	    set test_name ""
	    set before_sql ""
	    set test_sql ""
	    set after_sql ""
	    set is_benchmark 1
	    set results [list]
	    set test_tcl [list]
	    lappend test_tcl $before_test
	    lappend test_tcl $backend_before_test
	    lappend test_tcl $test_data
	    # if there's something special for this backend, add it now
	    if {$backend_name ne "" && $other_values(LUMO_TEST_DIR) eq "" && \
		    [file exists [file join $backend_notfork $test_file]]} {
		set fd [open [file join $backend_notfork $test_file]]
		lappend test_tcl [read $fd]
		close $fd
	    }
	    lappend test_tcl $backend_after_test
	    lappend test_tcl $after_test
	    set sqlite3_for_this_run $sqlite3_to_test
	    apply \
		[list {} "\
		    upvar benchmark_options options \
			  is_benchmark is_benchmark \
			  test_name name \
			  before_sql before_sql \
			  test_sql sql \
			  after_sql after_sql \
			  results results \
			  expanded_extra extra_builds \
			  expanded_targets targets \
			  sqlite3_for_this_run sqlite3 \
			  build_dir build_dir
		    [join $test_tcl]"]
	    if {$is_benchmark || $operation ne "benchmark"} {
		incr test_number
		if {$other_values(COPY_DATABASES) ne ""} {
		    if {[file exists $temp_db_name]} {
			set dest_file \
			     [format $other_values(COPY_DATABASES) $benchmark $test_number]
			set dest_dir [file dirname $dest_file]
			if {! [file isdirectory $dest_dir]} {
			    file mkdir $dest_dir
			}
			file copy $temp_db_name $dest_file
		    }
		}
		set sqlfd [open $temp_sql_file w]
		puts $sqlfd $before_sql
		close $sqlfd
		exec $sqlite3_to_test $temp_db_name < $temp_sql_file > /dev/null
		set sqlfd [open $temp_sql_file w]
		puts $sqlfd $test_sql
		close $sqlfd
		if {$other_values(COPY_SQL) ne ""} {
		    set dest_file [format $other_values(COPY_SQL) $benchmark $test_number]
		    set dest_dir [file dirname $dest_file]
		    if {! [file isdirectory $dest_dir]} {
			file mkdir $dest_dir
		    }
		    file copy $temp_sql_file $dest_file
		}
		if {$operation eq "benchmark"} {
		    set delay 1000
		    exec sync; after $delay;
		}
		set status "?"
		set oct [times]
		set owt [clock microseconds]
		if {[catch {
		    if {$benchmark_options(DISCARD_OUTPUT) eq "off"} {
			set output [exec $sqlite3_for_this_run $temp_db_name < $temp_sql_file]
		    } else {
			exec $sqlite3_for_this_run $temp_db_name < $temp_sql_file > /dev/null
		    }
		} res opt]} {
		    set nwt [clock microseconds]
		    set nct [times]
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
		    set nwt [clock microseconds]
		    set nct [times]
		    set status "OK"
		    if {$benchmark_options(DISCARD_OUTPUT) eq "off" && [llength $results] > 0} {
			set ol [split $output \n]
			if {[llength $results] > [llength $ol]} {
			    set status "NRESULTS"
			} else {
			    for {set rnum 0} {$rnum < [llength $results]} {incr rnum} {
				if {! [regexp [lindex $results $rnum] [lindex $ol $rnum]] } {
				    set status "RESULT[expr $rnum + 1]"
				    break
				}
			    }
			}
		    }
		    if {$status eq "OK"} {
			incr tests_ok
		    } else {
			incr tests_fail
		    }
		}
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
		if {$benchmark_options(DISCARD_OUTPUT) eq "off"} {
		    update_test $run_id $test_number [list \
			"output-size"      [string length $output] \
		    ]
		}
		set total_time [expr $total_time + $wt]
		puts [format "%s%8s %9.3f %3d %s" $space $status $wt $test_number $test_name]
	    }
	}
	set end_run [clock seconds]
	update_run $run_id [list \
	    "end-run"         $end_run \
	    "tests-ok"        $tests_ok \
	    "tests-intr"      $tests_intr \
	    "tests-fail"      $tests_fail \
	]
	puts [format "%s        %10.3f (total time)" $space $total_time]
	lappend test_result $benchmark $tests_ok $tests_intr $tests_fail
	# delete temp database
	file delete -force $temp_db_dir
    }
}

if {$operation eq "test"} {
    puts ""
    puts "*** Test summary:"
    set width 0
    foreach {title tests_ok tests_intr tests_fail} $test_result {
	set t [string length $title]
	if {$t > $width} {set width $t}
    }
    puts [format "%-${width}s   OK INTR FAIL" "TARGET"]
    set all_ok 1
    foreach {title tests_ok tests_intr tests_fail} $test_result {
	puts [format "%-${width}s %4d %4d %4d" $title $tests_ok $tests_intr $tests_fail]
	if {$tests_intr > 0 || $tests_fail > 0} {set all_ok 0}
    }
    if {$all_ok == 0} {exit 1}
}

# all done

exit 0

