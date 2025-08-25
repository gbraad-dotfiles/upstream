packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "ubuntu" {
  accelerator       = "kvm"
  disk_image        = true
  iso_url           = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
  iso_checksum      = "sha256:834af9cd766d1fd86eca156db7dff34c3713fbbc7f5507a3269be2a72d2d1820"
  output_directory  = "output-ubuntu"
  format            = "qcow2"
  memory            = 2048
  disk_size         = "20480"
  ssh_username      = "root"
  ssh_password      = "password"
  ssh_wait_timeout  = "30m"
  net_device        = "virtio-net"
  headless          = true

  cd_files = [".packer/ubuntu/cloud-init/user-data", ".packer/ubuntu/cloud-init/meta-data"]
  cd_label = "CIDATA"

  shutdown_command  = "shutdown -P now"
  shutdown_timeout  = "1m"

  qemuargs = [
    ["-boot", "c"]
  ]
}

build {
  name    = "ubuntu"
  sources = ["source.qemu.ubuntu"]

  provisioner "shell-local" {
    script = ".packer/machinefile.sh"
    environment_vars = [
      "TARGET=ubuntu",
      "SSH_HOST=${build.Host}",
      "SSH_PORT=${build.Port}"]
  }

  # disable cloud-init
  provisioner "shell" {
    inline = [
      "echo 'GRUB_CMDLINE_LINUX=\"cloud-init=disabled\"' | tee -a /etc/default/grub",
      "update-grub",
      "touch /etc/cloud/cloud-init.disabled"
    ]
  }

  # enable DHCP
  provisioner "shell" {
    inline = [
      "apt-get update",
      "apt-get install -y ifupdown",
      "rm -f /etc/netplan/50-cloud-init.yaml"
    ]
  }

  provisioner "file" {
    content     = <<-EOT
      source /etc/network/interfaces.d/*

      auto lo
      iface lo inet loopback

      allow-hotplug ens3
      iface ens3 inet dhcp
      EOT
    destination = "/etc/network/interfaces"
  }

  # disable root and password login
  provisioner "shell" {
    inline = [
      "rm -f /etc/ssh/sshd_config.d/00-packer.conf"
    ]
  }
}
