function start_odfs() {
    if [[ ${SLURM_JOB_CONSTRAINTS} =~ "BEEOND" ]] ; then
            
        source /etc/odfs/odfs.conf
        source /etc/odfs/functions.sh

        ODFSDEBUG=1
        ODFSDEBUGLOG=/tmp/odfs-slurm.$SLURM_JOB_ID
        if [[ $ODFSDEBUG == 1 ]];then
                #create file initial
                echo "prolog beeond AAAA" > $ODFSDEBUGLOG
                echo "constraint found $SLURM_JOB_ID" >> $ODFSDEBUGLOG
        fi

        job_hosts=`scontrol show hostnames`
        head_node=`echo $job_hosts | awk '{print $1;}'`
        if [[ $ODFSDEBUG == 1 ]];then
                echo $job_hosts >> $ODFSDEBUGLOG 
                echo $head_node >> $ODFSDEBUGLOG 
                export >> $ODFSDEBUGLOG 
        fi

        #Create dd-imagefile and loopback mountpoint if configured
        if [[ ${ODFSLOOPBACK} == 1 ]]; then
                #This prologue must run on all allocated nodes
                #check your slurm config PrologFlags should contain "Alloc"
                odfs_create_loopmount
        fi

        #Start beeond only on job master node
        nodefile=/tmp/odfs-slurm-nodelist.$SLURM_JOB_ID
        echo $job_hosts | tr " " "\n" > $ODFSNODEFILE 2>&1

        #option with more metadata server
        case "${SLURM_JOB_CONSTRAINTS}" in
                BEEOND)
                        MDS_NODES=1
                        ;;
                BEEOND_4MDS)
                        NODE_CNT=$(wc -l < ${ODFSNODEFILE})
                        if [[ ${NODE_CNT} -lt 4 ]] ; then
                            MDS_NODES=${NODE_CNT}
                        else
                            MDS_NODES=4
                        fi
                        ;;
                BEEOND_MAXMDS)
                        MDS_NODES=$(wc -l < ${ODFSNODEFILE})
                        ;;
                *)    
                        #catchall
                        MDS_NODES=1
                        ;;
        esac

        if [[ ${SLURMD_NODENAME} == $head_node ]] ; then
            # create connauthfile
            # need pdcp to distribute
            # Recomendation: create extra ssh key for beeond
            # Add key to /usr/bin/beeond
            PDSH_SSH_ARGS_APPEND="-i /root/.ssh/odfs -p 1234"
            export PDSH_SSH_ARGS_APPEND
            #define in odfs.conf -> ODFSCONNAUTHFILE=/tmp/odfs_caf
            RANDOMCRED=`/usr/bin/openssl rand -base64 12`
            CRED="${SLURM_JOB_ID}-${RANDOMCRED}"
            echo ${CRED}  > ${ODFSCONNAUTHFILE}
            chmod 600 ${ODFSCONNAUTHFILE}
            pdcp -w ${SLURM_JOB_NODELIST} ${ODFSCONNAUTHFILE} ${ODFSCONNAUTHFILE} 

            /usr/bin/beeond start -n ${ODFSNODEFILE} -m ${MDS_NODES} -d ${ODFSLOOPBACKMOUNTPOINT}  -c ${ODFSMOUNTPOINT} -i /tmp/beeond.tmp -P -F -L /tmp -f /etc/beegfs/beeond
        fi

        #remount nosuid nodev
        mount -o remount,nosuid,nodev ${ODFSMOUNTPOINT} 
        ###
        mkdir ${ODFSMOUNTPOINT}/stripe_1
        /usr/bin/beegfs-ctl --setpattern --numtargets=1 --mount=${ODFSMOUNTPOINT} ${ODFSMOUNTPOINT}/stripe_1 > /dev/null  2>&1
        mkdir ${ODFSMOUNTPOINT}/stripe_8
        /usr/bin/beegfs-ctl --setpattern --numtargets=8 --mount=${ODFSMOUNTPOINT} ${ODFSMOUNTPOINT}/stripe_8 > /dev/null  2>&1
        mkdir ${ODFSMOUNTPOINT}/stripe_16
        /usr/bin/beegfs-ctl --setpattern --numtargets=16 --mount=${ODFSMOUNTPOINT} ${ODFSMOUNTPOINT}/stripe_16 > /dev/null  2>&1
        mkdir ${ODFSMOUNTPOINT}/stripe_32
        /usr/bin/beegfs-ctl --setpattern --numtargets=32 --mount=${ODFSMOUNTPOINT} ${ODFSMOUNTPOINT}/stripe_32 > /dev/null  2>&1  
        #Default stripe count = 4
        mkdir ${ODFSMOUNTPOINT}/stripe_default
        mkdir ${ODFSMOUNTPOINT}/stripe_4
        #/usr/bin/beegfs-ctl --setpattern --numtargets=4 --mount=${ODFSMOUNTPOINT} ${ODFSMOUNTPOINT}/stripe_4 > /dev/null  2>&1
        #/usr/bin/beegfs-ctl --setpattern --numtargets=4 --mount=${ODFSMOUNTPOINT} ${ODFSMOUNTPOINT}/stripe_default > /dev/null  2>&1

        chown ${SLURM_JOB_USER}  ${ODFSMOUNTPOINT}/stripe_1 ${ODFSMOUNTPOINT}/stripe_4 ${ODFSMOUNTPOINT}/stripe_8 ${ODFSMOUNTPOINT}/stripe_16 ${ODFSMOUNTPOINT}/stripe_32  ${ODFSMOUNTPOINT}/stripe_default 
        ### 
        #Create Status file for cleanup in epilog
        echo "USER: ${SLURM_JOB_USER}" > ${ODFSSTATUSFILE}
        echo "JOBID: ${SLURM_JOB_ID}" >> ${ODFSSTATUSFILE}
        echo "MOUNTPOINT: ${ODSMOUNTPOINT}" >> ${ODFSSTATUSFILE}
        chmod 700 ${ODFSSTATUSFILE}
        chmod 700 ${ODFSDEBUGLOG}
        echo "export ODFS=${ODFSMOUNTPOINT}"


        # Only needed when using extra ssh daemon for startup
        ##Wait before ssh shutdown
        ##Create nodefile on every node
        #NODECOUNT=`cat  $ODFSNODEFILE | wc -l`
        ##Maxium wait time - 3s per node - only a rough estimate
        ## If mountpoint is there, we just break the loop earlier
        #WAITTIME=$[$NODECOUNT*2+30]
        #while [[ 0 -le $WAITTIME ]]
        #do
        #        mountpoint -q ${ODFSMOUNTPOINT}
        #        if [[ "$?" -eq "0" ]]
        #        then
        #                break
        #        fi
        # 
        #         sleep 1
        #         WAITTIME=$[$WAITTIME-1]
        #done 
                            
    fi
}





function stop_odfs() {
    #Little bit messy, SLURM_JOB_CONSTRAINTS not available in epilog
    #so we are checking for the ODFS Status file

    source /etc/odfs/odfs.conf
    ODFSDEBUG=1
    if [[ -r ${ODFSSTATUSFILE} ]] ; then
            source /etc/odfs/odfs.conf
            source /etc/odfs/functions.sh
    
            ODFSDEBUGLOG=/tmp/odfs-slurm.$SLURM_JOB_ID
            if [[ $ODFSDEBUG == 1 ]];then
                    echo "EPILOGUE prolog beeond AAAA" >> $ODFSDEBUGLOG
                    export >> $ODFSDEBUGLOG
            fi

            job_hosts=`scontrol show hostnames`
            head_node=`echo $job_hosts | awk '{print $1;}'`
            if [[ $DEBUG == 1 ]];then
                    echo $job_hosts >> $ODFSDEBUGLOG
                    echo $head_node >> $ODFSDEBUGLOG
                    export >> $ODFSDEBUGLOG 
                fi
            #First stop beeond, we are doing quick stoplocal
            #make shure epilogue is executed on all nodes 
            #be careful if you have other beegfs pretty rough way to kill anything beegfs related
            odfs_stop_beeond
            odfs_kill_beeond
            if [[ ${ODFSLOOPBACK} == 1 ]]; then
                    #This epilogue must run on all allocated nodes
                    #check your slurm config
                    #Removing Loopback mountpoint
                    odfs_remove_loopmount
            fi
    fi
    #removing probably leftover files
    for file in ${ODFSIMAGE} ${ODFSNODEFILE} ${ODFSSTATUSFILE} ${ODFSCONNAUTHFILE}; do
        if [ -e $file ]; then
        rm $file 
        fi
    done
    if [ -d ${ODFSMOUNTPOINT} ]; then
        rmdir ${ODFSMOUNTPOINT}
    fi
    #rm ${ODFSIMAGE} ${ODFSNODEFILE} ${ODFSMOUNTPOINT} ${ODFSSTATUSFILE} ${ODFSSTATUSFILE} ${ODFSDEBUGLOG}
    #only remove status files if ODFSDEBUG is not enabled   
    if [[ $ODFSDEBUG == 0 ]];then
            rm ${ODFSSTATUSFILE} ${ODFSDEBUGLOG}
    fi
        
}



# Job specific temp dir gets created before prolog
# is running, so clean up temp dirs only in epilog
case "${SCRIPT_NAME}" in
    prolog*) start_odfs
             ;;
    epilog*) stop_odfs
             ;;
esac

