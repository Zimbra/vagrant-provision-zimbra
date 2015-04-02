# vagrant-provision-zimbra
[Vagrant](https://www.vagrantup.com/) provisioning script for various [Zimbra](https://www.zimbra.com/) related environments along with examples, notes and hints on getting things up and running.

In order to use these, you'll need to have Vagrant [installed](https://www.vagrantup.com/downloads.html) and [get familiar](https://docs.vagrantup.com/v2/) with how to use it.

## What's here...

* [vsetup-ubuntu.sh](vsetup-ubuntu.sh)

A vagrant provisioning script for ubuntu (known to work with 14.04 LTS):
```
Usage: vsetup-ubuntu.sh <[-b][-d][-r]>
  environment type (choose all desired zimbra related environments):
    -b  == build       ThirdParty FOSS (fpm,gcc,headers,libs,etc.)
    -d  == development Full ZCS builds (ant,java,maven,...)
    -r  == runtime     consul, mariadb, redis, memcached

  Note: runtime uses non-standard ZCS components (instead of
        building the components from ThirdParty)
```

* [Vagrantfile-example](Vagrantfile-example)

Copy this example Vagrantfile to the name 'Vagrantfile' in the location of the VM to be provisioned.  Set the variables as appropriate for your environment:

```
VMBOX = "ubuntu/trusty64" # ref: https://atlas.hashicorp.com/boxes/search
HOSTNAME = "zpc"          # name of VM, convenient to use same name as p4 client
SRCDIR = "/site"          # map source directory into the VM
HOMEDIR = "/home/ppearl"  # map my home into the VM

# provisioning script and args
#   PPATH = "./vsetup-ubuntu.sh"
#   PARGS = ...  # -b == build, -d == dev, -r == runtime
PPATH =
  "https://raw.githubusercontent.com/plobbes/vagrant-provision-zimbra/master/vsetup-ubuntu.sh"
PARGS = ["-d"]
```

### Potential issues:

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
$ vagrant up ubuntu/trusty64 --provider virtualbox
$ vagrant ssh     # -- -R 1066:127.1.1.1:1066 -R 1443:127.1.1.1:1443
$ vagrant halt
$ vagrant destroy # irreversible!
```

* [vsetup-ubuntu.custom.sh](vsetup-ubuntu.custom.sh)

An second (example) script that could also be called via the vagrant provisioning process to setup more custom environmental related settings.

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

- [ ] CentOS setup script(s)
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
