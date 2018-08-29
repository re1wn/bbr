#!/bin/bash
#
# This script performs the top-level orchestration of the TCP congestion
# control testing scripts in this directory. It does the following:
#
# - builds a kernel on the local machine
# - copies and installs and boots the kernel on test machines
# - copies test scripts to test machines
# - sets up test machines
# - runs tests on the test machines
# - generates graphs on the test machines
# - copies graphs from test machines to a local output directory
#
# Usage:
#   OUTDIR=$D VMS="<ip1> <ip2> <ip3> <ip4> <ip5>" \
#     tools/testing/selftests/net/nsperf/orchestrate.sh
# 

if [ -z "$OUTDIR" ]; then
    echo "Error: OUTDIR environment variable must be set." >&2
    exit 1
fi

set -x  # print commands before executing
set -e  # exit upon error

###########
# helpers

waitssh()
{
    local RHOST=$1; shift

    date
    echo "trying ssh to $RHOST ..."

    until alarm 5 ssh -o ConnectTimeout=2 "$RHOST" "uptime; uname -a"
    do
        sleep 1
        date
        echo "trying ssh to $RHOST ..."
    done

    echo "done waiting for ${RHOST}."
    date
}

# Create the list of 5 tests we run:
declare -a ALL_TESTS=(coexist random_loss shallow bufferbloat ecn_bulk)
NUM_TESTS=${#ALL_TESTS[@]}

# Turn the list of VMs into an array:
declare -a ALL_VMS=($VMS)
NUM_VMS=${#ALL_VMS[@]}

# Verify the user passed 5 different machines to run the 5 tests:
if (( $NUM_VMS != $NUM_TESTS )); then
    echo "Error: VMS list must have exactly $NUM_TESTS elements." >&2
    exit 1
fi

###########
# building and installing kernels:

date
for VM in $VMS; do
    echo "installing on VM = $VM .............................................."
    time ./gce-install.sh -m ${VM}
    echo
done

###########
# wait for kernels to finish rebooting

date
echo "waiting for reboots to start..."
sleep 15

date
for VM in $VMS; do
    echo "waiting for VM = $VM ................................................"
    waitssh "${VM}"
    echo
done


###########
# copying tests to test VMs

date
rm -f /tmp/nsperf.tgz
tar -zcvf /tmp/nsperf.tgz tools/testing/selftests/net/nsperf/

for VM in $VMS; do
    echo "VM = $VM ........................................................"
    scp /tmp/nsperf.tgz "${VM}":/tmp/
    ssh "${VM}" "uname -a; sudo bash -c 'cd /root; rm -rf tools/testing/selftests/net/nsperf/ /root/iproute2/; tar -zxvf /tmp/nsperf.tgz'"
    echo
done
date

############
# set up machines w/ configure.sh and run tests with run_tests.sh:

for ((i=0; i<NUM_TESTS; i++)); do
    echo "$i ------------------------------------------------------------------"
    VM=${ALL_VMS[$i]}
    echo "VM = $VM"
    TEST=${ALL_TESTS[$i]}
    echo "TEST = $TEST"
    CMD="uname -a; nohup sudo bash -c '( cd /root/tools/testing/selftests/net/nsperf/; ./configure.sh ; tests=$TEST ./run_tests.sh ) > run_tests_out.txt 2>&1 &'"
    echo "CMD = $CMD"
    ssh "$VM" "$CMD"
    echo
done

##############
# graph results and copy graphs to local machine:

TIMESTAMP=`date +%Y-%m-%d-%H-%M-%S`
DIR="${OUTDIR}/${TIMESTAMP}/"
mkdir -p $DIR
echo "generating graphs and copying graphs to $DIR"
for ((i=0; i<NUM_TESTS; i++)); do
    echo "$i ------------------------------------------------------------------"
    VM=${ALL_VMS[$i]}
    echo "VM = $VM"
    TEST=${ALL_TESTS[$i]}
    echo "TEST = $TEST"
    CMD="uname -a; nohup sudo bash -c 'cd /root/tools/testing/selftests/net/nsperf/; rm -f /tmp/*png ./graphs/*png;tests=$TEST ./graph_tests.sh > graph_tests_out.txt 2>&1; cp -a graphs/*png /tmp/'"
    echo "CMD = $CMD"
    ssh "$VM" "$CMD"

    scp "${VM}":/tmp/*png "$DIR"
    echo "output in: $DIR"
    ls -l "$DIR"
    echo
    echo
done

echo "all output: "
find "$DIR"

rm -f /tmp/nsperf.tgz
echo "done."
