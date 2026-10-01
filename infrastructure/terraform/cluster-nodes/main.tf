resource "proxmox_virtual_environment_vm" "k3s_server" {
  name      = "k3s-server-01"
  node_name = "homelab"
  vm_id     = 301
  on_boot   = true
  started   = true

  clone {
    vm_id = 9000
    full  = true
  }

  cpu {
    cores = 4
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 8192
  }

  disk {
    datastore_id = "local-lvm"
    size         = 40
    interface    = "scsi0"
  }

  network_device {
    bridge = "vmbr0"
  }

  initialization {
    user_account {
      username = "ubuntu"
      password = var.vm_password
      keys     = [var.ssh_public_key]
    }

    ip_config {
      ipv4 {
        address = "192.168.1.201/24"
        gateway = "192.168.1.1"
      }
    }
  }

  operating_system {
    type = "l26"
  }
}
