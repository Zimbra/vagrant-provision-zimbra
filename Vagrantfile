# -*- mode: ruby -*-
# vi: set ft=ruby :

def load_conf(cfile)
  conf = Hash.new
  if File.exists?("VMBOX")
    print "loading VMBOX...\n" if ENV["DEBUG"]
    conf["VMBOX"] = IO.read("VMBOX").gsub(/\s+/,"")
  end
  if File.exists?(cfile)
    print "loading ", cfile, "...\n" if ENV["DEBUG"]
    File.open(cfile).each_line do |line|
      next if /^\s*(?:#|$)/.match(line)
      key, val = line.strip.split(/\s*=\s*/, 2)
      if /^'([^']*)'/.match(val) || /^"([^"]*)"/.match(val)
        val = $1
      elsif /^([^#]*)/.match(val)
        val = $1.strip
      end
      val = val.split(/\s+/) if /^PROVARGS$/.match(key)
      conf[key] = val
    end
  end
  return conf
end

# Notes:
# - boxes ref: https://atlas.hashicorp.com/boxes/search
# - set HOSTNAME based on config or current directory name
# - set PROVARGS based on HOSTNAME ("-d" if name ends in d or dev)
#   -b == build, -d == dev, -r == runtime
# Additional optional config items:
#   MYUSER, HOMEDIR, SRCDIR
conf = load_conf("Vagrantfile.conf")

conf["VMBOX"]    || abort("error: VMBOX not set, check VMBOX|Vagrantfile.conf file(s)")
conf["VMMEMORY"] ||= 4096
conf["VMCPUS"]  ||= 2
conf["HOMEDIR"]  ||= File.expand_path('~' + conf["MYUSER"]) if conf["MYUSER"]
conf["HOSTNAME"] ||= File.basename(File.dirname(File.absolute_path(__FILE__)))
conf["PROVARGS"] ||= ["-d"]
conf["PROVPATH"] ||= File.join(File.dirname(File.absolute_path(__FILE__)),
                               "vsetup.sh")

if /^(?:up|provision|ssh|status)/.match(ARGV[0])
  print "HOSTNAME (VMBOX): ", conf["HOSTNAME"], " (", conf["VMBOX"], ")\n"
  if /^(?:up|provision)/.match(ARGV[0])
    print "Provision path (args): ", conf["PROVPATH"], " (", conf["PROVARGS"] * " ", ")\n"
    if conf["SRCDIR"]
      print "SRCDIR: ", (conf["SRCDIR"] || ""), "\n"
    end
  end
end
conf.sort.each { |k, v| print "DEBUG: conf: ", k, " => ", v, "\n" } if ENV["DEBUG"]

VAGRANTFILE_API_VERSION = "2"
Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  if conf["VMBOX"] == "centos6"
    config.vm.provider :docker do |docker|
      docker.build_dir = conf["VMBOX"]
      docker.has_ssh = true
      docker.name = conf["HOSTNAME"]
    end
  else
    config.vm.box = conf["VMBOX"]
  end
  config.vm.host_name = conf["HOSTNAME"]
  if conf["HOMEDIR"]
    config.vm.synced_folder conf["HOMEDIR"],
                            "/home/" + File.basename(conf["HOMEDIR"])
  end

  # virtualbox: mmap broken on mapped filesystems
  # - ref: https://www.virtualbox.org/ticket/819
  if conf["SRCDIR"]
    config.vm.synced_folder conf["SRCDIR"], conf["SRCDIR"] #, type: "nfs"
  end
  # map vagrant user/grp to me, not root
  config.nfs.map_uid = Process.uid
  config.nfs.map_gid = Process.gid

  config.vm.provider :lxc do |lxc|
    lxc.container_name = conf["VMNAME"] if conf["VMNAME"]
    lxc.customize "network.link", conf["VMBRIDGE"] if conf["VMBRIDGE"]
  end
  config.vm.provider :virtualbox do |vb|
    vb.memory = conf["VMMEMORY"]
    vb.cpus = conf["VMCPUS"]
    vb.name = conf["VMNAME"] if conf["VMNAME"]
  end
  config.vm.provider :libvirt do |vd|
    vd.memory = conf["VMMEMORY"]
    vd.cpus = conf["VMCPUS"]
  end
  config.vm.provider :parallels do |prl|
    prl.memory = conf["VMMEMORY"]
    prl.cpus = conf["VMCPUS"]
    prl.name = conf["VMNAME"] if conf["VMNAME"]
  end
  config.vm.provider :vmware_fusion do |vmw|
    vmw.vmx["memsize"] = conf["VMMEMORY"]
    vmw.vmx["numvcpus"] = conf["VMCPUS"]
    vmw.vmx["displayName"] = conf["VMNAME"] if conf["VMNAME"]
  end

  # http://fgrehm.viewdocs.io/vagrant-cachier
  if config.vm.box.is_a?(String) && Vagrant.has_plugin?("vagrant-cachier")
    config.cache.scope = :box
  end

  # https://github.com/tmatilai/vagrant-timezone
  if Vagrant.has_plugin?("vagrant-timezone")
    config.timezone.value = :host
  end

  # this triggers a warning with lxc, but we work around that earlier
  if conf["VMBRIDGE"]
    config.vm.network "public_network", bridge: conf["VMBRIDGE"]
  end

  # refs: nfs[1] with private_network[2] and dhcp conflicting host adapter[3]
  # 1. http://docs.vagrantup.com/v2/synced-folders/nfs.html
  # 2. http://docs.vagrantup.com/v2/networking/private_network.html
  # 3. https://github.com/mitchellh/vagrant/issues/3083 workaround:
  #    VBoxManage dhcpserver remove --netname HostInterfaceNetworking-vboxnet0
  if conf["PROVPATH"]
    config.vm.provision "ppath", type: "shell", path: conf["PROVPATH"], args: conf["PROVARGS"]
  end
  if conf["PROVCUSTOM"]
    config.vm.provision "shell", inline: conf["PROVCUSTOM"]
  end
end
