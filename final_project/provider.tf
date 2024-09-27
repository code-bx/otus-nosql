
terraform {
  required_version = ">= 0.13"
  required_providers {
    # https://cloud.yandex.com/en/docs/tutorials/infrastructure-management/terraform-quickstart
    yandex = {
      source = "yandex-cloud/yandex"
      version = "0.97.0"
    }
    # https://www.ansible.com/blog/providing-terraform-with-that-ansible-magic
    # https://github.com/ansible/terraform-provider-ansible
    ansible = {
      source  = "ansible/ansible"
      version = "1.1.0"
    }
  }
}

provider "yandex" {
  folder_id = "${var.yc_folder_id}"
  zone = "${var.yc_zone}"

  # Вместо указания service_account_key_file используется переменная
  # окружения YC_SERVICE_ACCOUNT_KEY_FILE (так меньше шансов на утечку
  # ключа).
}
