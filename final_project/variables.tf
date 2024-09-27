##
## Yandex Cloud provider vars
##

variable "yc_folder_id" {
  # Например значение возвращаемое командой
  #   yc config get folder-id
  type = string
}

variable "yc_boot_image_id" {
  # From: yc compute image list --folder-id standard-images \
  #       | grep " ubuntu-20-04-lts-v$(date +%Y)" | sort -k4,4V
  type = string
  default = "fd8cp9rjherlilnosipf"
}

variable "yc_zone" {
  type = string
  default = "ru-central1-a"
}

variable "yc_user" {
  type = string
  default = "yc-user"
}

variable "yc_ssh_pub_key_path" {
  type = string
  default = "~/.ssh/id_ed25519.pub"
}


##
## ClickHouse related variables
##

variable "keeper_count" {
  default = "3"
  description = "Number of ClickHouse keeper nodes"
}

variable "replicas" {
  default = "2"
  description = "Number of ClickHouse replicas per shard  (change only for a new cluster)"
}

variable "shards" {
  default = "1"
  description = "Number of ClickHouse shards (1 or more)"
}
