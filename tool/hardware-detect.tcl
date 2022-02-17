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

proc scsi_name {dev ls type} {
    if {$type ne ""} {
	set type " ($type)"
    }
    foreach s [split $ls \n] {
	if {[regexp {/([^\s/]+)\s*$} $s skip sd] && $sd eq $dev} {
	    regsub {^\[[^\[\]]+\]\s+\S+\s+} $s {} s
	    regsub {\s+/\S+\s*$} $s {} s
	    set r "$s$type"
	    regsub -all {\s+} $r " " r
	    puts $r
	    exit 0
	}
    }
}

proc device_name {dev} {
    # for some devices we can provide a generic name
    set type ""
    if {[regexp {^nvme} $dev]} { set type "NVME SSD" }
    if {[regexp {^mmcblk} $dev]} { set type "MMC/SD" }
    # see if lsscsi lists it
    catch {
	scsi_name $dev [exec lsscsi] $type
    }
    # if we do have a generic name, output it
    if {$type ne ""} {
	puts $type
	exit 0
    }
    # anything else we can try?
}

proc find_device {dev} {
    # if lsblk can find it... (Probably Linux only)
    catch {
	if {[regexp {\n(\S+)\s[^\n]*\n*$} [exec lsblk -s --raw $dev] skip phdev]} {
	    device_name $phdev
	}
    }
    if {$tcl_platform(os) eq "Linux" && [regexp {/vd[a-z]\d} $dev]} {
	puts "Virtio Block Device"
	exit 0
    }
    # add here more ways to figure out what something may be
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
			if {$t eq "tmpfs" || $t eq "mfs"} {
			    puts ramdisk
			    exit 0
			}
			# add any other type of network file system
			if {$t eq "nfs" || \
			    [regexp {^nfs} $t] || \
			    $t eq "ceph" || \
			    $t eq "afs" || \
			    $t eq "cifs" || \
			    $t eq "smbfs" || \
			    $t eq "coda"} \
			{
			    puts "network file system"
			    exit 0
			}
		    }
		    # a real local device... but what it may be?
		    if {[regexp {^(\S+)\s} $l skip d]} {
			find_device $d
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
    if {$tcl_platform(os) eq "FreeBSD"} {
	catch {
	    set cpu [exec sysctl -n hw.model]
	    puts [string trim $cpu]
	    exit 0
	}
    }
    if {$tcl_platform(os) eq "NetBSD"} {
	catch {
	    set cpu [exec sysctl -n machdep.cpu_brand]
	    puts [string trim $cpu]
	    exit 0
	}
    }
    # Linux has /proc/cpuinfo, NetBSD also has it if the kernel is
    # built with option COMPAT_LINUX; FreeBSD may have it in
    # /compat/linux - so if we got here without an answer, we
    # try them both
    catch {
	set f ""
	foreach ci [list "/proc/cpuinfo" "/compat/linux/proc/cpuinfo"] {
	    catch {
		set f [open $ci r]
		break
	    }
	}
	if {$f ne ""} {
	    set cpu ""
	    set hw ""
	    set model ""
	    foreach l [split [read $f] \n] {
		regexp -nocase {^model\s+name\s*:\s+(\S.*)$} $l skip cpu
		regexp -nocase {^model\s*:\s+([^\s\d].*)$} $l skip model
		regexp -nocase {^hardware\s*:\s+(\S.*)$} $l skip hw
	    }
	    close $f
	    if {"$hw$cpu" ne ""} {
		if {$hw eq ""} {
		    set name $cpu
		} elseif {$cpu eq ""} {
		    set name $hw
		} else {
		    set name "$cpu: $hw"
		}
		if {$model eq ""} {
		    puts $name
		} else {
		    puts "$name ($model)"
		}
		exit 0
	    }
	    if {$model ne ""} {
		puts $model
		exit 0
	    }
	}
    }
    # if we find out other ways to do this, we add them here
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
    }
    catch {
	set df [exec df $path]
	parse_df $df
    }
    # if we find out other ways to do this, we add them here
} else {
    puts stderr "Usage: hardware-detect.tcl       => hint for CPU_COMMENT"
    puts stderr "Usage: hardware-detect.tcl PATH  => hint for DISK_COMMENT"
    exit 1
}

