variable "yc_zone" {
  type = string
}

variable "yc_boot_image_id" {
  # From: yc compute image list --folder-id standard-images \
  #       | grep " ubuntu-20-04-lts-v$(date +%Y)" | sort -k4,4V
  type = string
}

variable "yc_subnet_id" {
  # From: yc vpc subnet list
  type = string
}

variable "yc_user" {
  type = string
  default = "yc-user"
}
