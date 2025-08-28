packer {
  required_plugins {
    qemu = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/qemu"
    }
  }
}

source "qemu" "fedora" {
  accelerator       = "kvm"
  disk_image        = true
  iso_url           = "https://download.fedoraproject.org/pub/fedora/linux/releases/42/Cloud/x86_64/images/Fedora-Cloud-Base-Generic-42-1.1.x86_64.qcow2"
  iso_checksum      = "sha256:e401a4db2e5e04d1967b6729774faa96da629bcf3ba90b67d8d9cce9906bec0f"
  output_directory  = "output-fedora"
  format            = "qcow2"
  memory            = 2048
  disk_size         = "20480"
  ssh_username      = "root"
  ssh_password      = "password"
  ssh_wait_timeout  = "30m"
  net_device        = "virtio-net"
  headless          = true

  cd_files = [".packer/fedora-cloud/cloud-init/user-data", ".packer/fedora-cloud/cloud-init/meta-data"]
  cd_label = "CIDATA"

  shutdown_command  = "shutdown -P now"
  shutdown_timeout  = "1m"

  qemuargs = [
    ["-boot", "c"]
  ]
}

build {
  name    = "fedora"
  sources = ["source.qemu.fedora"]

  provisioner "shell-local" {
    script = ".packer/machinefile.sh"
    environment_vars = [
      "TARGET=fedora-cloud",
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
