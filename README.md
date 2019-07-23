# TCP BBR v3 Release

This document gives a quick overview of Google's TCP BBR v3 release for Linux,
and how to download, build, install, and test it.

The TCP BBR v3 release is intended to enable research collaboration and wider
testing.  We encourage researchers to dive in and help evaluate/improve the BBR
algorithm and code. We welcome patches with good solutions to issues.

This document shows how to download, build, install, and test
a Linux kernel running TCP BBR v3.

## License

Like Linux TCP BBR v1, the v3 code is dual-licensed as both GPLv2 (like the
Linux kernel) and BSD. You may use it under either license.

## Viewing the TCP BBR v3 sources

You can view the current sources here:
[tcp_bbr.c](https://github.com/google/bbr/blob/v3/net/ipv4/tcp_bbr.c)

## Obtaining kernel sources with TCP BBR v3

There are two main options for downloading the code:

1. To create a new git repo starting from a Linux kernel with TCP BBR v3,
you can run:

```
git clone -o google-bbr -b v3  https://github.com/google/bbr.git
cd bbr/
```

2. To download the code into an existing git repo, you can use:

```
git remote add google-bbr https://github.com/google/bbr.git
git fetch google-bbr
git checkout google-bbr/v3
```

Note that if you already have a git repo that has imported the Linux source
tree, then the second option will be much faster and use much less space, since
it will only need to download the small deltas relative to the mainline Linux
source distribution.

## Building and installing the kernel

To build a Linux kernel with TCP BBR v3 support, copy that kernel to a target
(Debian or Ubuntu) test machine (bare metal or GCE), and reboot that machine,
you can use the following script, included in the TCP BBR v3 distribution:

```
./gce-install.sh -m ${HOST}
```

## Checking the kernel installation

Once the target test machine has finished rebooting, then ssh to the target
test machine and become root with sudo or equivalent. First check that the
machine booted the kernel you built above:

```
uname -a
```

You should see the branch name SHA1 hash, and build time stamp from the kernel
you built above.


Then check what congestion control modules are available with:
```
sysctl net.ipv4.tcp_available_congestion_control
```

You should see something like:
```
net.ipv4.tcp_available_congestion_control = reno bbr cubic dctcp
```

## Install test dependencies

Next, copy the test scripts to the target test machine with:

```
scp -r tools/testing/selftests/net/nsperf/ ${HOST}:/tmp/
```

Before running the tests for the first time, as a one-time step you'll need to
install the dependencies on the test machine, as root:

```
mv /tmp/nsperf /root/
cd /root/nsperf
./configure.sh
```

## Running TCP BBR v3 tests and generating graphs

To run the tests, ssh to the target test machine and become root with sudo or
equivalent. Then run the tests and generate graphs with:

```
cd /root/nsperf
./run_tests.sh
./graph_tests.sh
```

This will run for hours, and place the graphs in the ./graphs/ directory.

You can run and graph a subset of the tests by specifying the test by name as
an environment variable. For example:

```
cd /root/nsperf
tests=random_loss ./run_tests.sh
tests=random_loss ./graph_tests.sh
```

Enjoy!

## Release Notes and Details

### iproute2 patches to support functionality in the BBRv3 source release

The BBRv3 source release includes a patch for the iproute2 package to
support functionality in the BBRv3 test kernel:

- patch "ss" tool to output congestion control state for BBRv3:
  - [0001-ss-output-TCP-BBRv3-diag-information.patch](https://github.com/google/bbr/blob/v3/gtests/net/tcp/bbr/nsperf/0001-ss-output-TCP-BBRv3-diag-information.patch)

### ECN

This release of BBRv3 does not support ECN. Previous releases of BBRv2 and
BBRv3 had support for shallow-threshold, per-packet ECN signals, similar to the
style of ECN used by L4S and TCP Prague. However, the BBRv2 and BBRv3 response
to ECN was developed outside the L4S ecosystem, and was not sufficiently
similar to L4S TCP Prague to coexist well with TCP Prague. To avoid coexistence
issues with TCP Prague, this release omits support for ECN. We hope to provide
appropriate support for L4S-style ECN in future versions.

## FAQ

If you have questions about BBR, check the [BBR
FAQ](https://github.com/google/bbr/blob/master/Documentation/bbr-faq.md).
