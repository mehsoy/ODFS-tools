function odfs_create_loopmount() {
     #read config for adafs
     # contains
     #MKFSTYPE
     #MKFSOPTION
     #MOUNTOPTION
     #IMAGESIZE
#     if [[ -r ${ODFSCONFFILE} ]]; then
#        source  ${ODFSCONFFILE}
#     fi
     #since this machine does not have any free partition we are creating image and using loopback
     dd if=/dev/zero of=${ODFSIMAGE} bs=1 count=0 seek=${ODFSIMAGESIZE} status=none
     ${ODFSMKFSTYPE} ${ODFSMKFSOPTION} ${ODFSIMAGE} 
     mount ${ODFSMOUNTOPTION} ${ODFSIMAGE} ${ODFSLOOPBACKMOUNTPOINT}
}

function odfs_remove_loopmount() {
     i=0
     while [[ $i  -le 5 ]]
     do
        #adafs still mounted
        #logger "while loop for removing ${ODFSMOUNTPOINT} - run $i"
        kill_beeond 
        sleep 3
        mountpoint -q ${ODFSMOUNTPOINT}
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
        logger "running umount on ${ODFSLOOPBACKMOUNTPOINT}"
        /usr/bin/umount -d -f -v ${ODFSLOOPBACKMOUNTPOINT}
        sleep 1
        mountpoint -q ${ODFSLOOPBACKMOUNTPOINT}
        if [[ "$?" -ne "0" ]]
            then
                break
        fi
        k=$[$k+1]
     done

     #/usr/bin/umount -d -f -v ${ODFSLOOPBACKMOUNTPOINT}  
     #logger "/usr/bin/umount -d -f -v ${ODFSLOOPBACKMOUNTPOINT}"
     #/usr/bin/umount -f -v ${ODFSLOOPDEVICE}  2>&1 >> /tmp/blub2.txt
     #/usr/sbin/losetup -d  ${ODFSLOOPDEVICE} 
     rm  ${ODFSIMAGE}
}

function odfs_start_beeond() {
    nodefile=/var/spool/torque/aux/$JOB_ID
    if [[ -r $nodefile ]]; then
        nodes=$(cat $nodefile | uniq)
    fi
    #write nodefile
    for i in $nodes
    do
        echo "$i" >> ${ODFSNODEFILE} 
    done
    beeond start -q -n ${ODFSNODEFILE} -d ${ODFSLOOPBACKMOUNTPOINT}  -c ${ODFSMOUNTPOINT}
    echo "${JOB_USER}" > ${ODFSSTATUSFILE}
    echo "${JOB_ID}" >> ${ODFSSTATUSFILE}
    echo "${ODFSMOUNTPOINT}" >> ${ODFSSTATUSFILE}
    chmod 755 ${ODFSSTATUSFILE}
}

function odfs_kill_beeond() {
    /usr/bin/beeond stoplocal -i /tmp/beeond.tmp -q -L -c -u
    killall -q /opt/beegfs/sbin/beegfs-storage
    killall -q /opt/beegfs/sbin/beegfs-helperd
    killall -q /opt/beegfs/sbin/beegfs-mgmtd
    killall -q /opt/beegfs/sbin/beegfs-meta
    /usr/sbin/rmmod beegfs
    #logger "rmmod beegfs"
}

function odfs_stop_beeond() {
        #user requested adafs and now stop it
        #try the nice way
        #/usr/bin/beeond stop -q -n ${ODFSNODEFILE} -i /tmp/beeond.tmp -L -c
        /usr/bin/beeond stoplocal -q -i /tmp/beeond.tmp -L -c -u
        rm  ${ODFSNODEFILE}  ${ODFSSTATUSFILE} /tmp/beeond.tmp 
}

