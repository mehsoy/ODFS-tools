function odfs_create_loopmount() {
     dd if=/dev/zero of=${ODFSIMAGE} bs=1 count=0 seek=${ODFSIMAGESIZE} status=none
     ${ODFSMKFSTYPE} ${ODFSMKFSOPTION} ${ODFSIMAGE} 
     mount ${ODFSMOUNTOPTION} ${ODFSIMAGE} ${ODFSLOOPBACKMOUNTPOINT}
}

function odfs_remove_loopmount() {
     i=0
     while [[ $i  -le 5 ]]
     do
        #beeond still mounted
        #logger "while loop for removing ${ODFSMOUNTPOINT} - run $i"
        odfs_kill_beeond 
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

	if [ -e "${ODFSIMAGE}" ]; then 
           rm  ${ODFSIMAGE}
	fi
}


function odfs_kill_beeond() {
    /usr/bin/beeond stoplocal -i /tmp/beeond.tmp -q -L -c -u
    killall -q /opt/beegfs/sbin/beegfs-storage
    killall -q /opt/beegfs/sbin/beegfs-helperd
    killall -q /opt/beegfs/sbin/beegfs-mgmtd
    killall -q /opt/beegfs/sbin/beegfs-meta
    # check if module is loaded
    if [ -n "$(lsmod | grep beegfs)" ]; then
      /usr/sbin/rmmod beegfs
    fi
    # check if file exists
    if [ -e "/tmp/beeond.tmp" ]; then
       rm /tmp/beeond.tmp
    fi
    #logger "rmmod beegfs"
}

function odfs_stop_beeond() {
        #user requested adafs and now stop it
        #try the nice way
        #/usr/bin/beeond stop -q -n ${ODFSNODEFILE} -i /tmp/beeond.tmp -L -c
	logger "odfs stopping beeond"
        /usr/bin/beeond stoplocal -q -i /tmp/beeond.tmp -L -c -u
        # rm  $file  #${ODFSNODEFILE}  ${ODFSSTATUSFILE}  
	 
}

