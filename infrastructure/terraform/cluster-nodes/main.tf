resource "proxmox_virtual_environment_vm" "k3s_server" {
  name      = "k3s-server-01"
  node_name = "homelab"
  vm_id     = 301

  clone {
    vm_id = 9000
    full  = true
  }

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 4096
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

resource "proxmox_virtual_environment_vm" "k3s_worker_01" {
  name      = "k3s-worker-01"
  node_name = "homelab"
  vm_id     = 302

  clone {
    vm_id = 9000
    full  = true
  }

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 2048
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
        address = "192.168.1.202/24"
        gateway = "192.168.1.1"
      }
    }
  }

  operating_system {
    type = "l26"
  }
}

resource "proxmox_virtual_environment_vm" "k3s_worker_02" {
  name      = "k3s-worker-02"
  node_name = "homelab"
  vm_id     = 303

  clone {
    vm_id = 9000
    full  = true
  }

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 2048
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
        address = "192.168.1.204/24"
        gateway = "192.168.1.1"
      }
    }
  }

  operating_system {
    type = "l26"
  }
}