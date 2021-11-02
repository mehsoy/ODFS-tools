function create_loopmount() {
     #read config for adafs
     # contains
     #MKFSTYPE
     #MKFSOPTION
     #MOUNTOPTION
     #IMAGESIZE
     if [[ -r ${ADAFSCONFFILE} ]]; then
        source  ${ADAFSCONFFILE}
     fi
     #since this machine does not have any free partition we are creating image and using loopback
     dd if=/dev/zero of=${ADAFSIMAGE} bs=1 count=0 seek=${ADAFSIMAGESIZE} status=none
     ${ADAFSMKFSTYPE} ${ADAFSMKFSOPTION} ${ADAFSIMAGE} 
     mount ${ADAFSMOUNTOPTION} ${ADAFSIMAGE} ${ADAFSLOOPBACKMOUNTPOINT}
}

function remove_loopmount() {
     i=0
     while [[ $i  -le 5 ]]
     do
        #adafs still mounted
        #logger "while loop for removing ${ADAFSMOUNTPOINT} - run $i"
        kill_beeond 
        sleep 3
        mountpoint -q ${ADAFSMOUNTPOINT}
        if [[ "$?" -ne "0" ]]
            then
                break
        fi
        i=$[$i+1]
     done
     #message "removing loopmount"
     k=0
     while [[ $k  -le 5 ]]
     do
        logger "running umount on ${ADAFSLOOPBACKMOUNTPOINT}"
        /usr/bin/umount -d -f -v ${ADAFSLOOPBACKMOUNTPOINT}
        sleep 1
        mountpoint -q ${ADAFSLOOPBACKMOUNTPOINT}
        if [[ "$?" -ne "0" ]]
            then
                break
        fi
        k=$[$k+1]
     done

     #/usr/bin/umount -d -f -v ${ADAFSLOOPBACKMOUNTPOINT}  
     #logger "/usr/bin/umount -d -f -v ${ADAFSLOOPBACKMOUNTPOINT}"
     #/usr/bin/umount -f -v ${ADAFSLOOPDEVICE}  2>&1 >> /tmp/blub2.txt
     #/usr/sbin/losetup -d  ${ADAFSLOOPDEVICE} 
     rm  ${ADAFSIMAGE}
}

function start_beeond() {
    nodefile=/var/spool/torque/aux/$JOB_ID
    if [[ -r $nodefile ]]; then
        nodes=$(cat $nodefile | uniq)
    fi
    #write nodefile
    for i in $nodes
    do
        echo "$i" >> ${ADAFSNODEFILE} 
    done
    beeond start -q -n ${ADAFSNODEFILE} -d ${ADAFSLOOPBACKMOUNTPOINT}  -c ${ADAFSMOUNTPOINT}
    echo "${JOB_USER}" > ${ADAFSSTATUSFILE}
    echo "${JOB_ID}" >> ${ADAFSSTATUSFILE}
    echo "${ADAFSMOUNTPOINT}" >> ${ADAFSSTATUSFILE}
    chmod 755 ${ADAFSSTATUSFILE}
}

function kill_beeond() {
    /usr/bin/beeond stoplocal -i /tmp/beeond.tmp -q -L -c -u
    killall -q /opt/beegfs/sbin/beegfs-storage
    killall -q /opt/beegfs/sbin/beegfs-helperd
    killall -q /opt/beegfs/sbin/beegfs-mgmtd
    killall -q /opt/beegfs/sbin/beegfs-meta
    /usr/sbin/rmmod beegfs
    #logger "rmmod beegfs"
}

function stop_beeond() {
        #user requested adafs and now stop it
        #try the nice way
        #/usr/bin/beeond stop -q -n ${ADAFSNODEFILE} -i /tmp/beeond.tmp -L -c
        /usr/bin/beeond stoplocal -q -i /tmp/beeond.tmp -L -c -u
        rm  ${ADAFSNODEFILE}  ${ADAFSSTATUSFILE} /tmp/beeond.tmp 
}

