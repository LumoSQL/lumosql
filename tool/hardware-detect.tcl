#!/usr/bin/tclsh

# try to detect defaults for DISK_COMMENT and CPU_COMMENT; this is inherently
# non-portable, so if we cannot do it we don't give an error, just produce
# empty output

# Copyright 2022 The LumoSQL Authors
#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2022 The LumoSQL Authors

###############################################################################

# with no arguments, provide defaults for CPU_COMMENT
# with 1 argument, provide defaults for DISK_COMMENT

proc device_name_linux {dev devname} {
    # first see if lsblk is installed and can find it; if not we just use
    # the device "df" gave us, which means we won't know how to map LVM
    # volumes to real devices
    catch {
	if {[regexp {\n(\S+)\s[^\n]*\n*$} [exec lsblk -s --raw $dev] skip devname]} {
	    # continue with rest of detecting; now $devname is the physical
	    # device name
	}
    }
    switch -regexp -matchvar v $devname {
	{^(vd[a-z])\d*$} {
	    set basedev [lindex $v 1]
	    set f [open "/sys/block/$basedev/device/vendor" r]
	    set vendorid [string trim [read $f]]
	    close $f
	    if {$vendorid ne ""} { return $vendorid }
	}
	{^nvme\d+n\d+} {
	    set basedev [lindex $v 0]
	    set f [open "/sys/block/$basedev/device/model" r]
	    set model [string trim [read $f]]
	    close $f
	    if {$model ne ""} { return "$model (NVME SSD)" }
	}
	{^(sd[a-z])\d*$} {
	    set basedev [lindex $v 1]
	    set f [open "/sys/block/$basedev/device/model" r]
	    set model [string trim [read $f]]
	    close $f
	    set vendor ""
	    catch {
		set f [open "/sys/block/$basedev/device/vendor" r]
		set vendor [string trim [read $f]]
		close $f
		if {$vendor eq "ATA"} { set vendor "" }
	    }
	    if {$model ne ""} {
		if {$vendor ne ""} {
		    return "$vendor $model"
		} else {
		    return $model
		}
	    } elseif {$vendor ne ""} {
		return $vendor
	    }
	}
	{^mmcblk\d+} {
	    set basedev [lindex $v 0]
	    set f [open "/sys/block/$basedev/device/name" r]
	    set name [string trim [read $f]]
	    close $f
	    if {$name ne ""} { return "$name (SD/MMC card)" }
	}
	# TODO other device name patterns
    }
    # not known or not understood -- anything else we can try?
    return ""
}

proc device_name_freebsd {dev devname} {
    catch {
	# we may have a name like /dev/gpt/... try to translate it to a real device
	# not doing anything like XML parsing, just finding the bits we need
	set xml [exec sysctl -n kern.geom.confxml]
	set idx0 0
	while {[regexp -indices -start $idx0 {<geom(.*?)</geom>} $xml m0]} {
	    set idx0 [lindex $m0 1]
	    set prov [string range $xml [lindex $m0 0] $idx0]
	    set idx1 0
	    set name ""
	    set found 0
	    while {[regexp -indices -start $idx1 {<name>([^<>]+)</name>} $prov m1 n]} {
		set idx1 [lindex $m1 1]
		set dn [string range $prov [lindex $n 0] [lindex $n 1]]
		if {$devname eq $dn} {
		    set found 1
		} else {
		    set name $dn
		}
	    }
	    if {$found && $name ne ""} {
		set devname $name
		break
	    }
	}
    }
    switch -regexp -matchvar v $devname {
	{^vtbd(\d+)} {
	    set devnum [lindex $v 1]
	    set v [exec sysctl -n "dev.vtblk.$devnum.%pnpinfo"]
	    regexp {vendor=0x([[:xdigit:]]+)} $v skip vendorid
	    regsub {^0*} $vendorid "0x" vendorid
	    return $vendorid
	}
	# TODO other device name patterns
    }
    # not known or not understood -- anything else we can try?
    return ""
}

proc find_device {dev} {
    set devname $dev
    regsub {^/dev/} $devname {} devname

    # if we know how to do things for this OS... if not just return
    switch $::tcl_platform(os) {
	Linux   { set name [device_name_linux   $dev $devname] }
	FreeBSD { set name [device_name_freebsd $dev $devname] }
	default { return }
    }

    if {$name eq ""} { return }
    if {$name eq "0x1af4" } {
	# Get the latest Virtio specification with: 
	#     git clone git://git.kernel.org/pub/scm/virt/kvm/mst/virtio-text.git
	#     sh makehtml.sh
	#
	# Section 4.1.2 PCI Device Discovery says: 
	#   
	#   "Any PCI device with PCI Vendor ID 0x1AF4, and PCI Device ID 0x1000
	#   through 0x107F inclusive is a virtio device. The actual value within
	#   this range indicates which virtio device is supported by the device. 
	#   The PCI Device ID is calculated by adding 0x1040 to the Virtio Device
	#   ID, as indicated in section 5. Additionally, devices MAY utilize a
	#   Transitional PCI Device ID range, 0x1000 to 0x103F depending on the
	#   device type."
	puts "Virtio Block Device"
    } else {
	puts $name
    }
    exit 0
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

proc try_sysctl {key} {
    catch {
	set cpu [exec sysctl -n $key]
	puts [string trim $cpu]
	exit 0
    }
}

proc try_cpuinfo {path} {
    catch {
	set f [open $path r]
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

# some places don't have sbin in PATH but we may need things from there
array set env [list PATH "$env(PATH):/sbin:/usr/sbin"]
if {[llength $argv] == 0} {
    switch $tcl_platform(os) {
	Linux {
	    try_cpuinfo "/proc/cpuinfo"
	}
	FreeBSD {
	    try_sysctl "hw.model"
	    try_cpuinfo "/compat/linux/proc/cpuinfo"
	}
	NetBSD {
	    try_sysctl "machdep.cpu_brand"
	    try_cpuinfo "/proc/cpuinfo"
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

