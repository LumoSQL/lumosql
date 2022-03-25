#!/bin/bash 
#
# Submit LumoSQL benchmark / test runs to a cluster
#
# LumoSQL: https://lumosql.org/
# Cluster scripts: https://lumosql.org/src/lumosql/dir?ci=tip&name=kbench
#
# Copyright 2022 The LumoSQL Authors under the terms contained in LICENSES/MIT
#
# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2022 The LumoSQL Authors
# SPDX-ArtifactOfProjectName: LumoSQL
# SPDX-FileType: Code
# SPDX-FileComment: Original by Dan Shearer, 2022

# Set defaults

PROGNAME=`basename $0`
LOCKFILE="/tmp/$PROGNAME"    # trivial mkdir(1) locking good enough for this use case
OUTMAKEFRAG="/tmp/$PROGNAME.Makefile.include"
MAKEFRAG="./Makefile.include"
LOGFILE="./"$PROGNAME".log"
DEBUG=""
DRYRUN=""

PrintHelp() {

	echo " "
	echo "$PROGNAME"
	echo " "
	echo " Submit a LumoSQL benchmarking/test job to a cluster. The input Makefile fragment (which must exist)"
	echo " contains variables which can be overridden by the commandline or calculated by this tool, and then a new"
	echo " Makefile fragment is generated and submitted. Basic concurrency checking is done but this tool"
	echo " is easy to abuse. A simple logfile is created. It is best to omit references to DATASIZE in JOBNAME because"
	echo " this script adds the name."
	echo " "
	echo "   mandatory options:"
	echo "      none yet."
	echo " "
	echo "   optional options:"
	echo "      -j specify job name, eg \"bench-ds-inteli7-sqlite-all\". Default is \$JOBNAME."
	echo "      -c cluster address, eg \"tovenaar.example.org\". Default is \$CLUSTER."
	echo "      -m filename of an input Makefile fragment, eg \"ClusterVars.txt\". Default is \"$MAKEFRAG\"."
	echo "      -l logfile name to append to. Default is \"$PROGNAME.log\"."
	echo "      -b beginning datasize."
	echo "      -e ending datasize. Required if -b specified."
	echo "      -d debug."
	echo "      -f fake dry run. Makes it easy to test jobs without actually submitting."
	echo "      -h this help text."
	echo " "
	echo "       example: "
	echo " "
	echo "              ./$PROGNAME -b 2 -e 20 -c tovenaar.example.org"
	exit 1
}

ErrorExit() {

	echo "Error: $1."
        echo "See \"$PROGNAME -h\" for help"
	exit 1
}


ExecCommand() {

	local thecommand=$1
	local return_output=$2  # if set, caller expects to catch the output
	local output

	if [[ ! -z $DEBUG ]]; then echo "about to run: $thecommand" ; fi

	echo $thecommand

	output=$(eval $thecommand)  # eval can go wrong in so many ways...

	if [[ ( $? != 0 ) ]]; then ErrorExit "Failed: $thecommand" ; fi

	if [[ ! -z $return_output ]]; then
		echo $output 
	fi

}

Cleanup() {

	if [[ -d $LOCKFILE ]]; then /usr/bin/rm -d $LOCKFILE ; fi
	if [[ -f $OUTMAKEFRAG ]]; then /usr/bin/rm $OUTMAKEFRAG ; fi
	echo "$(date +%Y-%m-%d) $PROGNAME finished" >> $LOGFILE 

}

GenerateOutMakefile() {

	# We have already sourced the Makefile fragment, if one exists, setting the DATASIZE variable
	local line
	local size=$1

	echo "# Output Makefile fragment from $PROGNAME" > $OUTMAKEFRAG
	if [[ ! -z $MAKEFRAG ]]; then
		while read line; do
			if [[ ! $line =~ .*"DATASIZE".* ]]; then
				echo $line >> $OUTMAKEFRAG
			fi
		done < $MAKEFRAG
	fi
	echo "DATASIZE="$size >> $OUTMAKEFRAG
	# eval "cat $OUTMAKEFRAG"
}

SubmitOneJob() {

	local cmd
	local output
	local summary
	local x
	local size=$1
	local myjobname

	myjobname=$JOBNAME-$size
	GenerateOutMakefile $size
	# break this string up because quoting in Bash related to eval() is fragile
	x="\"Authorization: Bearer $TOKEN\""
	cmd="curl -vv -L -H "$x" -X PUT $CLUSTER/job/$myjobname  --data-binary  $OUTMAKEFRAG 2>&1"

	if [[ $DRYRUN == "yes" ]]; then
		echo "Would have submitted: "$myjobname
	else
		output=$(ExecCommand "$cmd" yes)
		if [[ $output =~ .*"HTTP/2 403".* ]]; then
			summary="$(date +%Y-%m-%d) Authorisation error from cluster "
		else 
			summary="$(date +%Y-%m-%d) Submitted $myjobname "  # check actual return codes here
		fi
		echo $summary >> $LOGFILE
		echo $summary
	fi
}

#### Script starts here

mkdir $LOCKFILE || ErrorExit "Another instance of $PROGNAME is running"
trap Cleanup EXIT

while getopts ":j:c:m:l:b:e:dfh" flag; do
    case $flag in
        j) JOBNAME=$OPTARG;;
        c) CLUSTER=$OPTARG;;
        m) CMDMAKEFRAG=$OPTARG;;
	l) LOGFILE=$OPTARG;;
	b) BEGINSIZE=$OPTARG;;
	e) ENDSIZE=$OPTARG;;
	d) DEBUG="yes";;
	f) DRYRUN="yes";;
	h) HELPHELP="help";;
	\?) ErrorExit "Unknown option -$OPTARG" ;;
        :) ErrorExit "Missing option argument for -$OPTARG" ;;
        *) ErrorExit "Unimplemented option: -$OPTARG" ;;
    esac
done

if [[ $DEBUG == "yes" ]]; then
    echo "JOBNAME=$JOBNAME"
    echo "CLUSTER=$CLUSTER"
    echo "MAKEFRAG=$MAKEFRAG"
    echo "CMDMAKEFRAG=$MAKEFRAG"
    echo "LOGFILE=$LOGFILE"
    echo "BEGINSIZE=$BEGINSIZE"
    echo "ENDSIZE=$ENDSIZE"
    echo "DRYRUN=$DRYRUN"
    echo "DEBUG=yes"
    echo "HELPHELP=help"

    echo "TOKEN=$TOKEN"   # never set by this script
fi

if [[ ( $OPTIND -lt 2) || (! -z $HELPHELP) ]];   #change OPTIND when there are mandator parameters
then 
	PrintHelp ;
fi

if [[ -z $TOKEN ]];
then
	ErrorExit "Need to set \$TOKEN outside $PROGNAME"
fi

if [[ -z $JOBNAME ]];
then
	ErrorExit "Need to set \$JOBNAME either outside $PROGNAME or on the commandline"
fi

if [[ ! -z $CMDMAKEFRAG ]]; then
	if [[ ! -f $CMDMAKEFRAG ]]; then
		ErrorExit "Makefile fragment $CMDMAKEFRAG specified with -m but does not exist"
	else
		MAKEFRAG=$CMDMAKEFRAG
	fi
else
	if [[ ! -f $MAKEFRAG ]]; then
		# No input Makefile fragment available
		# Insist on having one for now; in future this script can generate one
		ErrorExit "Makefile fragment $MAKEFRAG does not exist"
	fi
fi

if [[ ! `which nmap` ]];
then
	ErrorExit "nmap needs to be in path"
fi

if [[ ( -z $JOBNAME ) ]]; then
	ErrorExit "\$JOBNAME must be set either by -j or outside $PROGNAME"
fi

if [[ ( -z $CLUSTER ) ]]; then
	ErrorExit "\$CLUSTER must be set either by -c or outside $PROGNAME"
else
	output=$(ExecCommand "nmap -p 443 $CLUSTER" yes)
	if [[ ! $output =~ .*"443/tcp open".* ]]; then
		ErrorExit "$CLUSTER is not reachable, according to nmap"
	fi
fi

if [[ ( ! -z $BEGINSIZE) && ( -z $ENDSIZE) ]]; then
	ErrorExit "If -b specified then -e is also required" ;
fi

if [[ ( ! -z $ENDSIZE) && ( -z $BEGINSIZE) ]]; then
	ErrorExit "If -e specified then -b is also required" ;
fi


if [[ ($EUID -eq 0) ]]; then
	ErrorExit "Unaudited script running as root." ;
fi

if [[ ( ! -z $BEGINSIZE ) ]]; then
	# The following tests if $BEGINSIZE is an integer, and also proves that bash is mad.
	# It works because bash throws an error if you pass strings to an integer comparison.
	[ -n "$BEGINSIZE" ] && [ "$BEGINSIZE" -eq "$BEGINSIZE" ] 2>/dev/null
	if [ $? -ne 0 ]; then
		ErrorExit "-b $BEGINSIZE not an integer" ;
	fi
	[ -n "$ENDSIZE" ] && [ "$ENDSIZE" -eq "$ENDSIZE" ] 2>/dev/null
	if [ $? -ne 0 ]; then
		ErrorExit "-e $ENDSIZE not an integer" ;
	fi
fi

echo "$(date +%Y-%m-%d) $PROGNAME started" >> $LOGFILE || ErrorExit "Cannot write to logfile $LOGFILE"

if [[ (-z $BEGINSIZE) ]]; then
	SubmitOneJob "1,1"
else
	i=$BEGINSIZE
	while [ $i -lt $ENDSIZE ];
	do
		SubmitOneJob "$i,$ENDSIZE"
		SubmitOneJob "$BEGINSIZE,$i"

		SubmitOneJob "$i,$BEGINSIZE"
		SubmitOneJob "$ENDSIZE,$i"

		i=$(( i += 2 ))
	done
fi

