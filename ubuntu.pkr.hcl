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
  shutdown_command  = "sudo shutdown -P now"
  net_device        = "virtio-net"
  headless          = true

  cd_files = ["./ubuntu/cloud-init/user-data", "./ubuntu/cloud-init/meta-data"]
  cd_label = "CIDATA"

  qemuargs = [
    ["-boot", "c"],
    ["-serial", "file:serial.log"]
  ]
}

build {
  name    = "ubuntu"
  sources = ["source.qemu.ubuntu"]

  provisioner "shell-local" {
    script = "machinefile.sh"
    environment_vars = [
      "TARGET=ubuntu",
      "SSH_HOST=${build.Host}",
      "SSH_PORT=${build.Port}"]
  }
}
