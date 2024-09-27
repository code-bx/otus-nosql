resource "yandex_vpc_network" "test-net" {
  name = "test-net"
}

resource "yandex_vpc_subnet" "ch-subnet" {
  zone = var.yc_zone
  network_id = "${yandex_vpc_network.test-net.id}"
  name = "ch-subnet"
  v4_cidr_blocks = ["10.128.0.0/24"]
}

locals {
  metadata_user_data = <<EOF
#cloud-config
ssh_pwauth: no
users:
- name: ${var.yc_user}
  sudo: ALL=(ALL) NOPASSWD:ALL
  shell: /bin/bash
  ssh_authorized_keys:
  - ${file(var.yc_ssh_pub_key_path)}
EOF
}

# Clickhouse Keeper VMs
resource "yandex_compute_instance" "keeper" {
  count = var.keeper_count
  name = "keeper${count.index+1}"
  hostname = "keeper${count.index+1}"
  metadata = {
    ssh-keys = "${file(var.yc_ssh_pub_key_path)}"
    user-data = local.metadata_user_data
  }

  resources {
    cores         = 2
    memory        = 4
    #core_fraction = 20 # FIXME: non-production only
  }

  scheduling_policy {
    #preemptible = true # FIXME: non-production
  }

  boot_disk {
    initialize_params {
      image_id = var.yc_boot_image_id
      size     = 10 //GB
    }
  }

  network_interface {
    # FIXME раскидать по зонам доступности
    subnet_id = yandex_vpc_subnet.ch-subnet.id

    # FIXME: без NAT apt не работает, а возиться с proxy, пока, нет желания
    nat        = true
  }

  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = var.yc_user
      host     = self.network_interface[0].nat_ip_address
    }
    inline = [ "/bin/true" ] # wait for ssh before ssh-keyscan
  }

}


locals {
  clickhouse_count = var.replicas * var.shards
}


resource "yandex_compute_instance" "clickhouse" {
  count = local.clickhouse_count
  name = "clickhouse${count.index+1}"
  hostname = "clickhouse${count.index+1}"
  metadata = {
    ssh-keys = "${file(var.yc_ssh_pub_key_path)}"
    user-data = local.metadata_user_data
  }

  # FIXME: раскидать по зонам доступности и подсетям
  resources {
    # FIXME: non-production only (в переменные)
    cores         = 2
    memory        = 8 //GB
    #core_fraction = 20
  }

  scheduling_policy {
    #preemptible = true # FIXME: non-production
  }

  boot_disk {
    initialize_params {
      image_id = var.yc_boot_image_id
      size     = 10 //GB
    }
  }

  network_interface {
    # FIXME раскидать по зонам доступности
    subnet_id = yandex_vpc_subnet.ch-subnet.id
    # FIXME: без NAT apt не работает, а возиться с apt-proxy, нет времени
    nat        = true
  }

  provisioner "remote-exec" {
    connection {
      type     = "ssh"
      user     = var.yc_user
      host     = self.network_interface[0].nat_ip_address
    }
    inline = [ "/bin/true" ] # wait for ssh before ssh-keyscan
  }

}

locals {
  ssh_hosts = concat(
    # clickhouse hosts (internal hosts)
    [for i, v in yandex_compute_instance.clickhouse :
      { addr = v.network_interface[0].nat_ip_address, port=22}],
    # keeper hosts (internal hosts)
    [for i, v in yandex_compute_instance.keeper :
      { addr = v.network_interface[0].nat_ip_address, port=22}],
    )
  ssh_known_hosts = "${path.root}/ansible/terraform.known_hosts"
}

resource "ansible_group" "all" {
  name = "all"
  variables = {
    clickhouse_shards = var.shards
  }
}

resource "ansible_host" "clickhouse" {
  count = local.clickhouse_count
  name = "clickhouse${count.index+1}"
  groups = ["clickhouse"]
  variables = {
    ansible_host = yandex_compute_instance.clickhouse[count.index].network_interface[0].nat_ip_address
    ansible_user = var.yc_user
    ansible_ssh_private_key_file = var.yc_ssh_pub_key_path
    ansible_ssh_common_args = join(" ", [
      "-o UserKnownHostsFile=${abspath(local.ssh_known_hosts)}",
    ])
    ansible_python_interpreter   = "/usr/bin/python3"
    clickhouse_host_internal_addr = yandex_compute_instance.clickhouse[count.index].network_interface[0].ip_address
    clickhouse_net_internal_cidr = yandex_vpc_subnet.ch-subnet.v4_cidr_blocks[0]
    clickhouse_shard_id = floor(count.index / var.replicas) + 1
    clickhouse_replica_id = (count.index % var.replicas) + 1
  }
}

resource "ansible_host" "keeper" {
  count = var.keeper_count
  name = "keeper${count.index+1}"
  groups = ["keepers"]
  variables = {
    ansible_host = yandex_compute_instance.keeper[count.index].network_interface[0].nat_ip_address
    ansible_user = var.yc_user
    ansible_ssh_private_key_file = var.yc_ssh_pub_key_path
    ansible_ssh_common_args = join(" ", [
      "-o UserKnownHostsFile=${abspath(local.ssh_known_hosts)}",
    ])
    ansible_python_interpreter   = "/usr/bin/python3"
    clickhouse_host_internal_addr = yandex_compute_instance.keeper[count.index].network_interface[0].ip_address
    clickhouse_net_internal_cidr = yandex_vpc_subnet.ch-subnet.v4_cidr_blocks[0]
    clickhouse_keeper_id = count.index+1
  }
}

# FIXME: явно есть гонки при сканировании ключей
resource "null_resource" "known_hosts" {
  provisioner "local-exec" {
    command = <<EOT
rm -f ${local.ssh_known_hosts};
%{ for i, host in local.ssh_hosts }
ssh-keyscan -p ${host.port} ${host.addr} >> ${local.ssh_known_hosts};
%{ endfor ~}
EOT
    interpreter = ["/bin/bash", "-c"]
  }
}
