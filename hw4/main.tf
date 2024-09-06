# Non-production only (optimized for low cost)
resource "yandex_compute_instance" "vm" {
  count = 5
  name = "cb${count.index+1}"
  hostname = "cb${count.index+1}"

  resources {
    cores         = 4
    memory        = 4
    core_fraction = 20
  }

  scheduling_policy {
    preemptible = true
  }

  boot_disk {
    initialize_params {
      image_id = "${var.yc_boot_image_id}"
      //type     = "network-ssd-nonreplicated"
      size     = 10 //GB
    }
  }

  network_interface {
    subnet_id = "${var.yc_subnet_id}"
    nat       = true
  }

  metadata = {
    ssh-keys = "${file("~/.ssh/id_ed25519.pub")}"
    user-data = "#cloud-config\nssh_pwauth: no\nusers:\n- name: ${var.yc_user}\n  sudo: ALL=(ALL) NOPASSWD:ALL\n  shell: /bin/bash\n  ssh_authorized_keys:\n  - ${file("~/.ssh/id_ed25519.pub")}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get upgrade -y",
      "curl -O https://packages.couchbase.com/releases/couchbase-release/couchbase-release-1.0-amd64.deb",
      "sudo dpkg -i ./couchbase-release-1.0-amd64.deb",
      "sudo apt-get update",
      "sudo apt-get install couchbase-server -y"
    ]

    connection {
      type        = "ssh"
      host        = "${self.network_interface[0].nat_ip_address}"
      user        = "${var.yc_user}"
    }
  }

}
