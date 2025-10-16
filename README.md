
# Introduction #

This script dispatches fence requests from the scoutfs quorum nodes.

All scoutfs installations require fencing to be setup. Including
single node systems.

It supports fencing nodes using ipmitool, powerman, or VSphere,
depending on the configuration used. SSH access is also required for
all of these to properly function.

Documentation for the script, configuration,
and operations is available at [ScoutFS
Fencing](https://docs.versity.com/docs/scoutfs-fencing).

This script must be installed on ALL active quorum nodes, so make
sure to repeat the full installation instructions on every node.


## Installation ##

Steps for installing the script:

 1. Install the scoutfs-fence-agent RPM on all quorum nodes.
 2. Copy the example ipmi configuration files from /usr/share/doc/scoutfs to
    /etc/scoutfs/ and edit them as needed.
 3. Enable and start the ScoutFS fencing service: `systemctl enable --now scoutfs-fenced`

Repeat on every node.


## Testing your Configuration ##

The fencing configuration can be tested by executing the script directly:

```bash
/usr/libexec/scoutfs-fenced/run/fence-remote-host
```
Example output:

Example 1: Properly configured:
```
  Test mode: verifying connection to manage all known nodes.
   ✓ PASS		192.168.124.12 (ssh)
   ✓ PASS		192.168.124.12 (ipmitool)
   ✓ PASS		192.168.124.126 (ssh)
   ✓ PASS		192.168.124.126 (ipmitool)
   ✓ PASS		192.168.124.80 (ssh)
   ✓ PASS		192.168.124.80 (ipmitool)
```

Example 2: Misconfigured SSH:
```
  Test mode: verifying connection to manage all known nodes.
  Unable to ssh to host "192.168.124.12"
   ✗ FAIL		192.168.124.12 (ssh)
   ✓ PASS		192.168.124.12 (ipmitool)
  Unable to ssh to host "192.168.124.126"
   ✗ FAIL		192.168.124.126 (ssh)
   ✓ PASS		192.168.124.126 (ipmitool)
  Unable to ssh to host "192.168.124.80"
   ✗ FAIL		192.168.124.80 (ssh)
   ✓ PASS		192.168.124.80 (ipmitool)
  Test mode failed.
```

The script will test connectivity to the configured control or
management plane and succeed if that works. Any errors encountered
during the testing will be shown to help diagnose configuration errors.


## Passwordless SSH Considerations ##

The script can utilize passwordless SSH between all nodes that
mount the ScoutFS filesystem but adds the ability to use non-root
identities. If using a non-root user, the following parameters can
be added to the `/etc/scoutfs/scoutfs-ipmi.conf` configuration file:

```
SSH_USER=user
SSH_IDENTS="-i /etc/secret/scoutfs_1_rsa -i /etc/secret/scoutfs_2_rsa"
```

These parameters will modify the SSH command used in the script to
log in as `user` and use the private keys defined in the `SSH_IDENTS`
parameter.

The corresponding public key must be added to the remote hosts
`authorized_keys` file. An easy way to do this is to use `ssh-copy-id
-i /etc/secret/scoutfs_1_rsa` (with or without `.pub` will work).

## Powerman ##

Powerman can be used in environments that do not allow node-to-node BMC connections. The `powerman`

> [!IMPORTANT]
> Versity does not directly support Powerman. While we can provide guidance and example configurations, we do not debug or provide fixes for Powerman.

### Installation ###

The `powerman` package is part of the EPEL repository. Refer to [EPEL](https://docs.fedoraproject.org/en-US/epel/) to install the EPEL repository on your system. Usually, one can do `dnf install epel-release`.

The `powerman` package can be installed after the EPEL repository is enabled:

```bash
dnf install -y powerman
```

> [!IMPORTANT]
> By default the `powerman` command installed by `powerman` package is world executable. We recommend securing access to the `powerman` command by adjusting the permissions to 700 with `chmod 700 /bin/powerman`.

#### Where to Install Powerman ####

The `powerman` package will need to be installed on the designated node(s) that have BMC access to the ScoutAM nodes as well as all ScoutFS quorumn nodes. The ScoutFS quorum nodes will use the `pm` command to issue remote power status and off commands to the Powerman servers.

Multiple Powerman servers are supported to enable redundancy if one Powerman server is unavailable.

### Configuration ###

The configuration file for Powerman is `/etc/powerman/powerman.conf`. Here is an example configuration for Dell systems with iDRAC that support the `ipmipower` command:

```
listen "0.0.0.0:10101"
include "/etc/powerman/ipmipower.dev"
device "ipmi_radia" "ipmipower" "/usr/sbin/ipmipower -D LAN_2_0 --wait-until-on --wait-until-off -u admin -p password -h radia[1-5]-ipmi |&"
node "radia[1-5]"    "ipmi_radia" "radia[1-5]-ipmi"
```

> [!NOTE]
> Any change to the `/etc/powerman/powerman.conf` file requires the `powerman` service to be restarted.

### Starting/Stoping Powerman ###

The `powerman` service can be controlled with the `systemctl` command.

Starting the `powerman` service:

```bash
systemctl start powerman
```

Stopping the `powerman` service:

```bash
systemctl stop powerman
```

### Verifying Powerman ###

Once `powerman` is configured and running on one or more designated Powerman servers, the configuration can be validated by checking the power status of all nodes from a ScoutFS quorum member.

Example querying the power state of all configured nodes:

```bash
powerman -h admin -q
```

Example output:

```
on:      radia[1-5]
off:
unknown:
```

### ScoutFS Fencing Configuration ###

After validating the `powerman` configuration, the host definitions in `/etc/scoutfs/scoutfs-ipmi-hosts.conf` file are as follows:

```
10.0.0.100  powerman    v1,172.21.1.51:radia1
10.0.0.101  powerman    v1,172.21.1.51:radia2
10.0.0.102  powerman    v1,172.21.1.51:radia3
10.0.0.102  powerman    v1,172.21.1.51:radia4
10.0.0.102  powerman    v1,172.21.1.51:radia5
```

The fields for the Powerman configuration are as follows:

```
SCOUTFS_QUORUM_IP    powerman    PM_SRV1[,PM_SRV2]:PM_NODE
```

The first parameter `SCOUTFS_QUORUM_IP` is the IP address that ScoutAM uses for quorum communications. The second parameter is the mode `powerman`. The third parameter includes a comma separated list of Powerman servers followed by a colon (`:`) and the name of the node configured in the Powerman configuration.

The `PM_SRVN` parameter can support host names or IP addresses. The `PM_NODE` parameter must match a `node` parameter in `/etc/powerman/powerman.conf` on the Powerman servers.

## VMWare vSphere ##

The `fence-remote-host` script has been adapated to support fencing virtual machines in a VMWare vSphere environment. When using vSphere mode with fencing, the `fence-remote-host` script must be able to access the following API endpoints on your vSphere server:

[Create Session](https://developer.vmware.com/apis/vsphere-automation/latest/cis/api/session/post/)

[Get Power](https://developer.vmware.com/apis/vsphere-automation/latest/vcenter/api/vcenter/vm/vm/power/get/)

[Stop Power](https://developer.vmware.com/apis/vsphere-automation/latest/vcenter/api/vcenter/vm/vm/poweractionstop/post/)

### vSphere Authentication ###

The authentication information for vSphere is stored in `/etc/scoutfs/scoutfs-ipmi.conf` with the `VSPHERE_USER` and `VSPHERE_PASS` directives:

```bash
VSPHERE_USER=admin
VSPHERE_PASS=password
```

### vSphere Fencing Configuration ###

The host definitions for vSphere VMs are defined in `/etc/scoutfs/scoutfs-ipmi-hosts.conf` as follows:

```
10.0.0.200   vsphere   vsphere-admin:vm50001
10.0.0.201   vsphere   vsphere-admin:vm50002
10.0.0.202   vsphere   vsphere-admin:vm50003
```

The fields for the vSphere configuration are as follows:

```
SCOUTFS_QUORUM_IP  vsphere   VSPHERE_API_HOST:VM_IDENTIFIER
```

The first parameter `SCOUTFS_QUORUM_IP` is the IP address that ScoutAM uses for quorum communications. The second parameter is the mode `vsphere`. The third parameter includes the vSphere API host followed by a colon (`:`) and the VM identifier of type VritualMachine that can be obtained from vSphere.
