# vagrant-provision-zimbra
[Vagrant](https://www.vagrantup.com/) provisioning script for various [Zimbra](https://www.zimbra.com/) related environments along with examples, notes and hints on getting things up and running.

In order to use these, you'll need to have Vagrant [installed](https://www.vagrantup.com/downloads.html) and [get familiar](https://docs.vagrantup.com/v2/) with how to use it.

If you run into problems with the `fgrehm/centos-6-64-lxc` vagrant box, this supports the use of a [Docker](https://www.docker.com/) container with Vagrant (currently for centos6 only!), see the Docker website for [installation procedures](https://docs.docker.com/installation/).

## Quick Start

### Getting a box up...

First, you need to install Git and [Vagrant](https://www.vagrantup.com/), and clone this repository:

```
$ mkdir -p ~/vagrant/u14test
$ cd ~/vagrant/u14test/
$ git clone https://github.com/Zimbra/vagrant-provision-zimbra .
Cloning into '.'...
[snip]
```

Second, install a few convenient vagrant plugins: [`vagrant-timezone`](https://github.com/tmatilai/vagrant-timezone) ensures that the box gets the same timezone as the your machine, and [`vagrant-cachier`](https://github.com/fgrehm/vagrant-cachier) speeds up consecutive creations of the box. (Skip the latter for one-off creations, or to save a bit of disk space.)

```
$ vagrant install vagrant-timezone vagrant-cachier
Installing the 'vagrant-timezone' plugin. This can take a few minutes...
[snip]
```

A note on providers:

* On Linux, the `lxc` provider avoids the VM overhead, and so is very fast. Use it if possible — it requires the [`vagrant-lxc`](https://github.com/fgrehm/vagrant-lxc) plugin.
* The default [`virtualbox`](https://www.virtualbox.org/) provider is included with vagrant and works everywhere, but is somewhat slow. Vagrant will download *VirtualBox* if necessary.
* On OS X, the `parallels` provider is much faster than *VirtualBox*, but requires either *Parallels Desktop 9* or the *Pro* or *Business* editions of newer releases. The plugin is called [`vagrant-parallels`](https://github.com/Parallels/vagrant-parallels).
* *VMware Fusion* and *VMware Workstation* may work with the appropriate provider, but since the provider isn't freely available, it remains untested.
* The ``libvirt`` provider — from the [``vagrant-libvirt``](https://github.com/pradels/vagrant-libvirt) plugin — is a slightly faster alternative to *VirtualBox* on Linux. To use it, you'll need to install the [``vagrant-mutate``](https://github.com/sciurus/vagrant-mutate) plugin and convert the box: ``vagrant mutate ubuntu/trusty64 libvirt``

Now, deploy the appliance, and log into it.

```
$ vagrant up --provider virtualbox
$ vagrant ssh
```

Refs:
* vagrant cli - http://docs.vagrantup.com/v2/cli/

### Working with Zimbra code

The following wiki provides tips on working with Zimbra FOSS code:
* https://wiki.zimbra.com/wiki/Building_Zimbra_using_Git

If you're going to be doing ZCS development (PROVARGS = -d) under multiple VMs/Boxes, it might be worth while doing the git checkout in your home outside of the VM/box and then mapping that directory (via MYUSER and/or SRCDIR) into the VM by setting settings like these in Vagrantfile.conf:

```
#MYUSER = ppearl        # used to map /home/MYUSER into the VM
#SRCDIR = "/site"       # map this source directory into the VM
#PROVARGS = -d          # -b == build, -d == dev, -r == runtime
```

## Notes on what is here...

* [vsetup.sh](vsetup.sh)

A vagrant provisioning script for CentOS 6 & 7 and Ubuntu LTS:

```
Usage: vsetup.sh <[-b][-d][-r]>
  environment type (choose all desired zimbra related environments):
    -b  == build       ThirdParty FOSS (gcc,headers,libs,etc.)
    -d  == development Full ZCS builds (ant,java,maven,...)
    -r  == runtime     consul, mariadb, redis, memcached

  Note: runtime uses non-standard ZCS components (instead of
        building the components from ThirdParty)
```

The provided ``Vagrantfile.conf`` provides access to most settings you might want to play with for the VM to be provisioned:

* [Vagrantfile](Vagrantfile) and [Vagrantfile.conf](Vagrantfile.conf)

### Potential issues:

* vagrant up with box "fgrehm/centos-6-64-lxc" fails (ssh timeout)
  - ref: https://github.com/fgrehm/vagrant-lxc/issues/308
  - workaround: use VMBOX=centos6 (with docker backend provider)
```
$ echo "centos6" > VMBOX
$ vagrant up --provider docker
```

* virtualbox can have issues with mmap on filesystems mapped into the VM
  - ref: https://www.virtualbox.org/ticket/819
  - workaround (use NFS and be sure your firewall setup allows NFS):
```
    config.vm.synced_folder SRCDIR, SRCDIR, type: "nfs"
```

* nfs with private_network and dhcp conflicting host adapter
  - http://docs.vagrantup.com/v2/synced-folders/nfs.html
    - enable use of nfs in Vagrantfile
```
    config.vm.network "private_network", type: "dhcp"
```
  - http://docs.vagrantup.com/v2/networking/private_network.html
  - https://github.com/mitchellh/vagrant/issues/3083 workaround:
    - disable the virtualbox dhcpserver if you hit this problem
```
    VBoxManage dhcpserver remove --netname HostInterfaceNetworking-vboxnet0
```

Then start up the VM, ssh into it (possibly with port forwarding), stop it, and destroy it (if you're done with it!):

```console
$ vagrant up --provider virtualbox
$ vagrant ssh     # -- -R 1066:127.1.1.1:1066 -R 1443:127.1.1.1:1443
$ vagrant halt
$ vagrant destroy # irreversible!
```

* [vsetup.custom.sh](vsetup.custom.sh)

An second (example) script that could also be called via the vagrant provisioning process to setup more custom environmental related settings.  Before using something like this, consider setting PROVCUSTOM in Vagrantfile.conf to do the setup you require.  For example

```
PROVCUSTOM = groupadd -g 1001 automation; useradd -M -u 1001 -g automation -s /bin/bash robot1
```

In this file there are hints as to how to setup and use a tunnel between the VM and the host/laptop where you are running vagrant from.  With the right environment setup is possible to get p4 and reviewboard to work easily with code that is being shared between your host/laptop and the VM.

```
    # custom tunnel for perforce and reviewboard
    # - connect VM ports to preexisting tunnels on my laptop via:
    #   vagrant ssh -- -R 1066:127.1.1.1:1066 -R 1443:127.1.1.1:1443
    # - where:
    #   - .reviewboardrc has: REVIEWBOARD_URL="https://ztun:1443"
    #   - .p4config has:      P4PORT=ztun:1066
```

## TODO

- [ ] Provide more info/links on getting started with Vagrant?

## License

```
The MIT License (MIT)

Copyright (c) 2015 Phil Pearl

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```
