resource "random_password" "password" {
  count            = var.instances_number
  length           = 8
  special          = false
}

resource "vkcs_compute_keypair" "infraguys_key" {
  name       = "infraguys_key"
  public_key = file("~/.ssh/infraguys.pub")
}

# Get external network with Internet access
data "vkcs_networking_network" "internet_sprut" {
  name = "internet"
  sdn  = "sprut"
}

data "vkcs_compute_flavor" "basic" {
  name = "STD2-1-1"
}

variable "instances_number" {
  description = "Number of instances"
  type        = number
  default     = 250
}

variable "port_range_start" {
  description = "Port range start for DNAT"
  type        = number
  default     = 22000
}

variable "image_user" {
  description = "User name from OS image"
  type        = string
  default     = "debian"
}


data "vkcs_images_image" "debian" {
  # Both arguments are required to search an actual image provided by VKCS.
  visibility = "public"
  default    = true
  # Use properties to distinguish between available images.
  properties = {
    mcs_os_distro  = "debian"
    mcs_os_version = "12"
  }
}

# Create security groups to define networking access
resource "vkcs_networking_secgroup" "lab_main" {
  name        = "lab_main"
}

resource "vkcs_networking_secgroup_rule" "ssh" {
  description       = "SSH rule"
  security_group_id = vkcs_networking_secgroup.lab_main.id
  direction         = "ingress"
  protocol          = "tcp"
  # Specify SSH port
  port_range_max = 22
  port_range_min = 22
  # Allow access from any sources
  remote_ip_prefix = "0.0.0.0/0"
}
