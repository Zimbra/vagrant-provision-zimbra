# vagrant-provision-zimbra
[Vagrant](https://www.vagrantup.com/) provisioning script for various [Zimbra](https://www.zimbra.com/) related environments along with examples, notes and hints on getting things up and running.

In order to use these, you'll need to have Vagrant [installed](https://www.vagrantup.com/downloads.html) and [get familiar](https://docs.vagrantup.com/v2/) with how to use it.

If you run into problems with the fgrehm/centos-6-64-lxc vagrant box, this supports the use of a [Docker](https://www.docker.com/) container with Vagrant (currently for centos6 only!), see the Docker website for [installation procedures](https://docs.docker.com/installation/).

## Quick Start

### Getting a box up...

If you have git, [Vagrant](https://www.vagrantup.com/) [VirtualBox](https://www.virtualbox.org/) installed, here's a relatively quick way (using vagrant-lxc is faster!) to get a box up...

```
$ mkdir -p ~/vagrant/u14test
$ cd ~/vagrant/u14test/
$ git clone https://github.com/plobbes/vagrant-provision-zimbra .
Cloning into '.'...
[snip]
$ echo "ubuntu/trusty64" > VMBOX  # fgrehm/trusty64-lxc for vagrant-lxc
$ vagrant up --provider virtualbox 2>&1 | tee -a up.$(basename $PWD)
$ vagrant ssh
```

If you have [vagrant-lxc](https://github.com/fgrehm/vagrant-lxc) installed, you may want to one of the *-lxc vagrant boxes (VMBOX) listed below instead of using VirtualBox to avoid the VM overhead.  Also, if you frequently create/destroy VMs of the same type, consider using [vagrant-cachier](https://github.com/fgrehm/vagrant-cachier) to avoid having to redownload updated packages over and over again.

Refs:
* ubuntu/trusty64 - https://atlas.hashicorp.com/ubuntu/boxes/trusty64
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

A vagrant provisioning script for centos{6,7}/ubuntu{12,14}:

```
Usage: vsetup.sh <[-b][-d][-r]>
  environment type (choose all desired zimbra related environments):
    -b  == build       ThirdParty FOSS (gcc,headers,libs,etc.)
    -d  == development Full ZCS builds (ant,java,maven,...)
    -r  == runtime     consul, mariadb, redis, memcached

  Note: runtime uses non-standard ZCS components (instead of
        building the components from ThirdParty)
```

* [Vagrantfile](Vagrantfile) and [Vagrantfile.conf](Vagrantfile.conf)

The provided Vagrantfile.conf provides access to most settings you might want to play with for the VM to be provisioned.  Set the variables as appropriate for your environment:

```
# Notes:
# - HOSTNAME defaults to current directory name if not specified
# - PROVARGS defaults to "-b" unless HOSTNAME ends in d or dev ("-d")
#   -b == build, -d == dev, -r == runtime
# Additional optional config items:
#   MYUSER, HOMEDIR, SRCDIR

#HOSTNAME = somename    # defaults to basename of $PWD
#MYUSER = ppearl        # used to map my home into the VM
#SRCDIR = "/site"       # map my source directory into the VM

# provisioning script and args # -b == build, -d == dev, -r == runtime
# - set PROVARGS based on hostname (-d if name ends in d or dev)
#PROVARGS =                                    # config.vm.provision "args:"
#PROVPATH = vsetup.sh                          # config.vm.provision "path:"
#PROVCUSTOM = /vagrant/vsetup.custom.sh        # config.vm.provision "inline:"

# Note: optionally put the value for VMBOX in a file named VMBOX
# - boxes ref: https://atlas.hashicorp.com/boxes/search
#VMBOX = "fgrehm/precise64-lxc"
#VMBOX = "fgrehm/trusty64-lxc"
#VMBOX = "centos6"                # via docker
#VMBOX = "fgrehm/centos-6-64-lxc" # if this hangs, use docker...
#VMBOX = "frensjan/centos-7-64-lxc"
#VMBOX = "ubuntu/trusty64"
```

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

   Copyright 2015 Phil Pearl

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
