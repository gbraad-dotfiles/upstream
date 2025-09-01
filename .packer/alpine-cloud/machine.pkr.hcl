packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "alpine" {
  accelerator       = "kvm"
  disk_image        = true
  iso_url           = "https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/cloud/nocloud_alpine-3.22.1-x86_64-bios-cloudinit-r0.qcow2"
  iso_checksum      = "sha256:ada37d5c6dc47451dd9c6800229e5d085e9fa8a2d9c097cdcdb7237dd8f62f07"
  output_directory  = "output-alpine"
  format            = "qcow2"
  memory            = 2048
  disk_size         = "20480"
  ssh_username      = "root"
  ssh_password      = "password"
  ssh_wait_timeout  = "30m"
  net_device        = "virtio-net"
  headless          = true

  cd_files = [".packer/alpine-cloud/cloud-init/user-data", ".packer/alpine-cloud/cloud-init/meta-data"]
  cd_label = "CIDATA"

  shutdown_command  = "poweroff"
  shutdown_timeout  = "1m"

  boot_wait         = "1s"

  qemuargs = [
    ["-boot", "c"]
  ]
}

build {
  name    = "alpine"
  sources = ["source.qemu.alpine"]

  provisioner "shell-local" {
    script = ".packer/machinefile.sh"
    environment_vars = [
      "TARGET=alpine-cloud",
      "SSH_HOST=${build.Host}",
      "SSH_PORT=${build.Port}"]
  }

  # disable cloud-init
  provisioner "shell" {
    inline = [
      "touch /etc/cloud/cloud-init.disabled"
    ]
  }

  # disable root and password login
  provisioner "shell" {
    inline = [
      "rm -f /etc/ssh/sshd_config.d/00-packer.conf"
    ]
  }
}