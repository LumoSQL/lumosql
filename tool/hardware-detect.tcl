#!/usr/bin/tclsh

# try to detect defaults for DISK_COMMENT and CPU_COMMENT; this is inherently
# non-portable, so if we cannot do it we don't give an error

# Copyright 2022 The LumoSQL Authors
#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2020 The LumoSQL Authors

###############################################################################

# with no arguments, provide defaults for CPU_COMMENT
# with 1 argument, provide defaults for DISK_COMMENT

proc scsi_name {dev ls} {
    foreach s [split $ls \n] {
	if {[regexp {/([^\s/]+)\s*$} $s skip sd] && $sd eq $dev} {
	    set type "disk/SSD"
	    if {[regexp {^nvme} $dev]} { set type "NVME SSD" }
	    regsub {^\[[^\[\]]+\]\s+\S+\s+} $s {} s
	    regsub {\s+/\S+\s*$} $s {} s
	    set r "$type $s"
	    regsub -all {\s\s+} $r " " r
	    puts $r
	    exit 0
	}
    }
}

proc device_name {dev} {
    # see if lsscsi lists it
    catch {
	scsi_name $dev [exec lsscsi]
	exit 0
    }
    # anything else we can try?
}

proc find_device {dev} {
    # if lsblk can find it...
    catch {
	if {[regexp {\n(\S+)\s[^\n]*\n*$} [exec lsblk -s --raw $dev] skip phdev]} {
	    device_name $phdev
	    exit 0
	}
    }
    # add here more ways to figure out what something may be
    # and if nothing found
}

proc parse_df {df} {
    # remove the first line, headers
    regsub {^[^\n]*\n} $df {} df
    if {[regexp {\s(\S+)\s*$} $df skip mp]} {
	# OK the mount point is $mp ... now see if we can figure out the device
	catch {
	    set m [exec mount]
	    foreach l [split [exec mount] \n] {
		if {[regexp {\son\s+(\S+)\s} $l skip m] && $mp eq $m} {
		    if {[regexp {\stype\s+(\S+)} $l skip t]} {
			# add any other type of disks which are in fact a ramdisk
			if {$t eq "tmpfs"} {
			    puts ramdisk
			    exit 0
			}
			# add any other type of network file system
			if {$t eq "nfs" || [regexp {^nfs} $t] || $t eq "coda"} {
			    puts "network file system"
			    exit 0
			}
		    }
		    # a real local device... but what it may be?
		    if {[regexp {^(\S+)\s} $l skip d]} {
			find_device $d
			exit 0
		    }
		    # unknown
		    exit 0
		}
	    }
	}
	# do we know other ways?
    }
}

# some places don't have sbin in PATH but we may need things from there
array set env [list PATH "$env(PATH):/sbin:/usr/sbin"]
if {[llength $argv] == 0} {
    catch {
	set f [open "/proc/cpuinfo" r]
	foreach l [split [read $f] \n] {
	    if {[regexp {^model\s+name\s+:\s+(.*)$} $l skip cpu]} {
		close $f
		puts $cpu
		exit 0
	    }
	}
	close $f
    }
    # if we know other ways to do this, we can add them here
} elseif {[llength $argv] == 1} {
    set path [lindex $argv 0]
    # the path may not have been created yet - but some parent must exist,
    # if nothing else the mount point, so look for that
    while {! [file exists $path]} {
	set npath [file dirname $path]
	if {$npath eq $path} {break}
	set path $npath
    }
    # figure out the mount point
    catch {
	set df [exec df -P $path]
	parse_df $df
	exit 0
    }
    catch {
	set df [exec df $path]
	parse_df $df
	exit 0
    }
    # if we know other ways to do this, we can add them here
} else {
    puts stderr "Usage: hardware-detect.tcl       => hint for CPU_COMMENT"
    puts stderr "Usage: hardware-detect.tcl PATH  => hint for DISK_COMMENT"
    exit 1
}

