packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "debian" {
  accelerator       = "kvm"
  disk_image        = true
  iso_url           = "https://cloud.debian.org/images/cloud/bookworm/20250814-2204/debian-12-generic-amd64-20250814-2204.qcow2"
  iso_checksum      = "sha256:1830fe2391308aa13008d196f2125570ad3fb03c5ca3585848b2f8361e877d7d"
  output_directory  = "output-debian"
  format            = "qcow2"
  memory            = 2048
  disk_size         = "20480"
  ssh_username      = "root"
  ssh_password      = "password"
  ssh_wait_timeout  = "30m"
  net_device        = "virtio-net"
  headless          = true

  cd_files = [".packer/debian-cloud/cloud-init/user-data", ".packer/debian-cloud/cloud-init/meta-data"]
  cd_label = "CIDATA"

  shutdown_command  = "shutdown -P now"
  shutdown_timeout  = "1m"

  qemuargs = [
    ["-boot", "c"]
  ]
}

build {
  name    = "debian"
  sources = ["source.qemu.debian"]

  provisioner "shell-local" {
    script = ".packer/machinefile.sh"
    environment_vars = [
      "TARGET=debian-cloud",
      "USER_PASSWD=password",
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
