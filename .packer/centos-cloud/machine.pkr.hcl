packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "centos" {
  accelerator       = "kvm"
  disk_image        = true
  iso_url           = "https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-x86_64-9-20250812.1.x86_64.qcow2"
  iso_checksum      = "sha256:1358744bd5df473eaf38defc80b039add9cf9306f35c14a97e7b122cea925777"
  output_directory  = "output-centos"
  format            = "qcow2"
  memory            = 2048
  disk_size         = "20480"
  ssh_username      = "root"
  ssh_password      = "password"
  ssh_wait_timeout  = "30m"
  net_device        = "virtio-net"
  headless          = true

  cd_files = [".packer/centos-cloud/cloud-init/user-data", ".packer/centos-cloud/cloud-init/meta-data"]
  cd_label = "CIDATA"

  shutdown_command  = "shutdown -P now"
  shutdown_timeout  = "1m"

  qemuargs         = [["-serial", "stdio"], ["-cpu", "host"]]
}

build {
  name    = "centos"
  sources = ["source.qemu.centos"]

  provisioner "shell-local" {
    script = ".packer/machinefile.sh"
    environment_vars = [
      "TARGET=centos-cloud",
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
