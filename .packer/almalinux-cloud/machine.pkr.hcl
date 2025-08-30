packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "almalinux" {
  accelerator       = "kvm"
  disk_image        = true
  iso_url           = "https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-9.6-20250522.x86_64.qcow2"
  iso_checksum      = "sha256:b08cd5db79bf32860412f5837e8c7b8df9447e032376e3c622840b31aaf26bc6"
  output_directory  = "output-almalinux"
  format            = "qcow2"
  memory            = 2048
  disk_size         = "20480"
  ssh_username      = "root"
  ssh_password      = "password"
  ssh_wait_timeout  = "30m"
  net_device        = "virtio-net"
  headless          = true

  cd_files = [".packer/almalinux-cloud/cloud-init/user-data", ".packer/almalinux-cloud/cloud-init/meta-data"]
  cd_label = "CIDATA"

  shutdown_command  = "shutdown -P now"
  shutdown_timeout  = "1m"

  qemuargs         = [["-serial", "stdio"], ["-cpu", "host"]]
}

build {
  name    = "almalinux"
  sources = ["source.qemu.almalinux"]

  provisioner "shell-local" {
    script = ".packer/machinefile.sh"
    environment_vars = [
      "TARGET=almalinux-cloud",
      "USER_PASSWD=password",
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
