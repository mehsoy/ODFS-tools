#!/bin/bash
set -x 

set DEBUG=1
echo "prolog beeond XXX" >> /tmp/slurm.$SLURM_JOB_ID
if [[ ${SLURM_JOB_CONSTRAINTS} =~ "beeond" ]] ; then
	source /etc/slurm/adafs/adafs.conf
	source /etc/slurm/adafs/functions.sh
##set -x
	job_hosts=`scontrol show hostnames`
	head_node=`echo $job_hosts | awk '{print $1;}'`
	if [[ $DEBUG == 1 ]];then
		echo $job_hosts >> /tmp/slurm.$SLURM_JOB_ID
		echo $head_node >> /tmp/slurm.$SLURM_JOB_ID 
		export >> /tmp/slurm.$SLURM_JOB_ID
	fi
#Create dd-imagefile and loopback mountpoint if configured
       if [[ ${ADAFSLOOPBACK} == 1 ]]; then
		#This prologue must run on all allocated nodes
		#check your slurm config
		create_loopmount
       fi

	#Start beeond only of job master node
	if [[ ${SLURMD_NODENAME} == $head_node ]] ; then
	      logfile=/tmp/slurm.prolog.$SLURM_JOB_ID
	      nodefile=/tmp/slurm_nodelist.$SLURM_JOB_ID
	      echo $job_hosts | tr " " "\n" > $ADAFSNODEFILE 2>&1

#	      /usr/bin/beeond start -n $nodefile -d /${LOCALDISK}/${SLURM_JOB_ID}/.beeond_data -c /${LOCALDISK}/${SLURM_JOB_ID}/beeond -P -F -L /tmp
	      /usr/bin/beeond start -n $ADAFSNODEFILE  -d ${ADAFSLOOPBACKMOUNTPOINT}  -c ${ADAFSMOUNTPOINT} -P -F -L /tmp 
	fi
	#Create Status file for cleanup in epilog
        echo "${SLURM_JOB_USER}" > ${ADAFSSTATUSFILE}
        echo "${SLURM_JOB_ID}" >> ${ADAFSSTATUSFILE}
        echo "${ADAFSMOUNTPOINT}" >> ${ADAFSSTATUSFILE}
        chmod 700 ${ADAFSSTATUSFILE}


fi
