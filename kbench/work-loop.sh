#!/bin/bash -xe

# Process LumoSQL benchmark/test jobs on a cluster. This is run on an 
# administration node.
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
# SPDX-FileComment: Original by Ruben De Smet, 2022

fossil clone https://lumosql.org/src/lumosql
cd lumosql

function resubmit() {
    if [ -e "Makefile.local" ]; then
        echo "Ayy matey, I was still working.  I'll resubmit my job ($JOB) to the server!"
        curl -vLJO -X PUT -H "Authorization: Bearer $SWQ_TOKEN" lumosql.opencloudedge.be/job/$JOB --data-binary @/lumosql/Makefile.local
        mv $DATABASE_NAME $DATABASE_NAME
    else
        echo "I wasn't working anymore, quitting clean"
    fi
    exit
}

trap resubmit SIGUSR1

while true; do
    # Get new work
    mkdir -p fetch-work
    pushd fetch-work
    while true; do
        STATUS=$(curl -sLJO -w "%{http_code}" -H "Authorization: Bearer $SWQ_TOKEN" lumosql.opencloudedge.be/next)
        if [ "$STATUS" == "204" ]; then
            rm next
            set +x
            sleep 10 &
            wait
        elif [ "$STATUS" == "200" ]; then
            set -x
            JOB=$(echo *)
            echo "Got job $JOB"
            break
        else
            echo "Got status $STATUS from server. I'm out."
            exit
        fi
    done
    popd
    # Update repo
    fossil update
    # Move work to new place
    mv fetch-work/* Makefile.local
    rm -rf fetch-work

    export CPU_COMMENT=$(awk -F': ' '/model name/{print $2; exit}' /proc/cpuinfo)
    export DATABASE_NAME=/mnt/results/$JOB-$(date +%Y-%m-%d).sqlite
    echo writing to $DATABASE_NAME

    make benchmark >> "$DATABASE_NAME.stdout" 2>> "$DATABASE_NAME.stderr" &
    wait

    echo Copying used settings to results dir
    mv Makefile.local $DATABASE_NAME.txt
    cat /proc/cpuinfo > $DATABASE_NAME.cpuinfo.txt
    cat /proc/meminfo > $DATABASE_NAME.meminfo.txt
done
