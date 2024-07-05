# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  config.vm.box = "debian/bookworm64"
  config.vm.disk :disk, size: "50GB", primary: true
  config.vm.disk :dvd, name: "installer", file: "./debian-testing-amd64-netinst.iso"

  config.vm.provider "virtualbox" do |vb|
    vb.cpus = 2
    vb.memory = 2048

    vb.gui = true
    vb.customize ["modifyvm", :id, "--vram", 128]
    vb.customize ["modifyvm", :id, "--firmware", "efi64"]
  end
end
