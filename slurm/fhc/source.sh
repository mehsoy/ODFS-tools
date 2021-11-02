#!/bin/bash


# Check if adafs is used within this job and set environment

if [[ -n "${SLURM_JOBID}" ]]; then
        if [[ ${SLURM_JOB_CONSTRAINTS} =~ "BEEOND" ]]; then
                if mountpoint -q /mnt/odfs/$SLURM_JOBID; then
                        export ODFS=/mnt/odfs/$SLURM_JOBID
                else
                        echo "REQUESTED ODFS not found"
                fi
        fi
fi

