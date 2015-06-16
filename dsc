#!/bin/bash
printf "Dirt Simple Comms v 0.1.6\n"
printf "........................\n"
ARGS="$*"
printf "Args used: $ARGS\n"
printf "........................\n"

function ctrl_c() {
    kill -1 $IHU_PID &> /dev/null
    #kill -1 $NC_IHU_PID &> /dev/null #2> /dev/null    #Seem to be getting som other PID
    #kill -1 $NC_UTALK_PID &> /dev/null #2> /dev/null  #Seem to be getting some other PID
    killall nc --quiet &> /dev/null
    kill -1 $SSH_PID1 &> /dev/null
    kill -1 $SSH_PID2 &> /dev/null
    kill -1 $SLIP_PID  &> /dev/null
    cat logo
    printf " NO CARRIER\n\n"
    if [[ $RESTART == "YES" ]] ; then
        RESTART=NO
        printf  "Loop Mode Enabled, Will Restart in 10 seconds..."
        sleep 10
        exec $0 $ARGS
    fi
    exit 0
}

function show_help() {
    printf "\nDirt Simple Comms v0.1\n"  
    printf "........................\n"
    printf "USAGE over ip\n"
    printf "    dsc -i x.x.x.x -r x.x.x.x --call\n"
    printf "AND on opposing machine\n"
    printf "    dsc -i x.x.x.x -r x.x.x.x --wait\n"
    printf "........................\n"
    printf "OR over serial via SLIP"
    printf "........................\n"
    printf "    dsc -i x.x.x.x -r x.x.x.x --slip /dev/ttyAMA0 --call\n"
    printf "AND on opposing machine\n"
    printf "    dsc -i x.x.x.x -r x.x.x.x --slip /dev/ttyUSB0 --wait\n"
    printf "........................\n"
    printf "OPTIONS\n"
    printf "    -u/, --user username       Remote SSH User Account\n"
    printf "    -l/, --local ip_addr       Local IP Address\n"
    printf "    -r/, --remote ip_addr      Remote IP Address\n"
    printf "    -s/, --slip serialDevice   Enable SLIP Mode over Serial Device, will use Local/Remote IP\n"
    printf "    -b/, --baud baudrate       Baud Rate (Default:115200)\n"
    printf "    --call                     Active Call Mode (i.e. client mode)\n"
    printf "    --wait                     Active Call Mode (i.e. client mode)\n" 
    printf "    --noinput                  Disable Audio Input for IHU\n"
    printf "    --loop                     Will re-run this script on exit (inf loop)\n"
    printf "........................\n\n"
}

#Initial Defaults
SLIP_BAUD=115200
SSH_USER="root"
ARG_VALID=0 # Simple argument validation mechanism (counter)
LOOP=NO     # Loop will trigger Restart=YES right before executing the final commands 
RESTART=NO

while [[ $# > 0 ]]
do
key="$1"

case $key in
    -l|--local)
    LOCAL_IP_ADDR="$2"
    shift # past argument=value
    ((ARG_VALID++))
    ;;
    -r|--remote)
    REMOTE_IP_ADDR="$2"
    shift
    ((ARG_VALID++))
    ;;
    -s|--slip)
    SLIP_DEV="$2"
    shift
    ;;
    -b|--baud)
    SLIP_BAUD="$2"
    shift
    ;;
    -u|--user)
    SSH_USER="$2"
    shift
    ;;
    --call)
    CALL_MODE=YES
    ((ARG_VALID++))
    ;;
    --wait)
    CALL_MODE=NO
    ((ARG_VALID++))
    ;;
    --noinput)
    IHU_ARGS="$1"
    ;;
    --loop)
    LOOP=YES
    ;;
    --help)
    show_help
    exit 0
    ;;
    *)
            # unknown option
    ;;
esac
shift # past argument or value
done

if [[ $ARG_VALID -ne 3 ]] ; then                  # Make final determination.
    printf "\n=== Invalid or missing arguments ===.\n\n"
    show_help
    exit 1
fi

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

if [[ $SLIP_DEV != "" ]] ; then                  # Make final determination.
    #Create and Configure our SLIP
    printf "configuring SLIP Between $LOCAL_IP_ADDR --> $REMOTE_IP_ADDR Over $SLIP_DEV..."
    slattach -p slip -s $SLIP_BAUD $SLIP_DEV > /dev/null &
    SLIP_PID=$!
    sleep 1
    ifconfig sl0 $LOCAL_IP_ADDR pointopoint $REMOTE_IP_ADDR up > /dev/null
    sleep 1
    route add -host $REMOTE_IP_ADDR dev sl0 > /dev/null
    printf "done\n"

    #Lets try to find the remote machine to prop up their slip interface
    printf "waiting for remote machine (making sure SLIP is up)..."
    ((count = 100))                            # Maximum number to try.
    while [[ $count -ne 0 ]] ; do
        ping -c 1 $REMOTE_IP_ADDR > /dev/null               # Try once.
        rc=$?
        if [[ $rc -eq 0 ]] ; then
            ((count = 1))                      # If okay, flag to exit loop.
        fi
        ((count = count - 1))                  # So we don't go forever.
    done

    if [[ $rc -eq 0 ]] ; then                  # Make final determination.
        printf "ok\n"

    else
        printf "failed\n"
        printf "could not find machine at $REMOTE_IP_ADDR\n"
        exit 1
    fi
    sleep 5
fi

if [[ $CALL_MODE == "YES" ]] ; then                  # Make final determination.
    printf "ok\n"
    #Time to create our ssh tunnel (local port forward)
    printf "creating ssh tunnel (user: $SSH_USER). make sure you shared your key!..."
    ssh -N -L 1794:localhost:1794 $SSH_USER@$REMOTE_IP_ADDR &
    SSH_PID1=$!
    ssh -N -L 1700:localhost:1700 $SSH_USER@$REMOTE_IP_ADDR &
    SSH_PID2=$!
    printf "done.\n"
    sleep 2
fi

#Now we must create a udp/tcp converter with netcat
if [[ $CALL_MODE == "YES" ]] ; then                  # Make final determination.
    printf "creating udp to tcp converter..."
    mkfifo /tmp/fifo_dsc-ihu &> /dev/null
    nc -k -l -u -p 1793 < /tmp/fifo_dsc-ihu | nc  localhost 1794 > /tmp/fifo_dsc-ihu & 
    NC_IHU_PID=$!

    mkfifo /tmp/fifo_dsc-utalk &> /dev/null
    nc -k -l -u -p 1701 < /tmp/fifo_dsc-utalk | nc localhost 1700 > /tmp/fifo_dsc-utalk &
    NC_UTALK_PID=$!
else
    printf "creating tcp to udp converter..."
    mkfifo /tmp/fifo_dsc-ihu &> /dev/null
    nc -k -l -p 1794 < /tmp/fifo_dsc-ihu | nc -u localhost 1793 > /tmp/fifo_dsc-ihu &
    NC_IHU_PID=$!

    mkfifo /tmp/fifo_dsc-utalk &> /dev/null
    nc -k -l -p 1700 < /tmp/fifo_dsc-utalk | nc -u localhost 1701 > /tmp/fifo_dsc-utalk &
    NC_UTALK_PID=$!
fi
printf "done.\n"

#If we are in loop mode, set RESTART=YES, trigger this way would allow to ctrl-c before getting here to exit
if [[ $LOOP == "YES" ]] ; then
    printf "Loop Mode Activated.\n"
    RESTART=YES
fi

#Start IHU
printf "Starting IHU.\n"
if [[ $CALL_MODE == "YES" ]] ; then
    printf "Calling\n"
    ihu --call localhost --nogui &> /dev/null &
else
    printf "Waiting for a call\n"
    ihu --wait --nogui $IHU_ARGS &> /dev/null &
fi
IHU_PID=$!

#Start utalk
printf "Starting utalk.\n"
if [[ $CALL_MODE == "YES" ]] ; then
    utalk -c localhost 1701
else
    utalk -s 1701
fi

#Exit Clean
ctrl_c
