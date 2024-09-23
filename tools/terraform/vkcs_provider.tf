terraform {
    required_providers {
        vkcs = {
            source = "vk-cs/vkcs"
        }
        ssh = {
            source = "loafoe/ssh"
            version = "2.7.0"
        }
    }

}

variable "user_email" {
  type = string
}

variable "user_password" {
  type = string
}

variable "project_id" {
  type = string
}

provider "vkcs" {
    # Your user account.
    username = var.user_email
    # The password of the account
    password = var.user_password
    # The tenant token can be taken from the project Settings tab - > API keys.
    # Project ID will be our token.
    project_id = var.project_id
    # Region name
    region = "RegionOne"
    auth_url = "https://infra.mail.ru:35357/v3/"
}
