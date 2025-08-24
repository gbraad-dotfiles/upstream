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
  iso_url           = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.0.0-amd64-netinst.iso"
  iso_checksum      = "sha256:e363cae0f1f22ed73363d0bde50b4ca582cb2816185cf6eac28e93d9bb9e1504"
  output_directory  = "output-debian"
  format            = "qcow2"
  memory            = 2048
  disk_size         = "20480"
  ssh_username      = "root"
  ssh_password      = "password"
  ssh_wait_timeout  = "30m"
  headless          = true
  http_directory    = "debian/http"
  boot_command = [
    "<esc><wait>",
    "install auto=true priority=critical preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg console=ttyS0,115200n8 <enter>"
  ]
  qemuargs = [
    ["-serial", "file:serial.log"]
  ]
}

build {
  name    = "debian"
  sources = ["source.qemu.debian"]

  provisioner "shell-local" {
    script = "machinefile.sh"
    environment_vars = [
      "TARGET=debian",
      "SSH_HOST=${build.Host}",
      "SSH_PORT=${build.Port}"]
  }
}
