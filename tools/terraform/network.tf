# Create networks
resource "vkcs_networking_network" "app" {
  name        = "lab_network"
  description = "Application network"
}

resource "vkcs_networking_subnet" "app" {
  name       = "lab_subnet"
  network_id = vkcs_networking_network.app.id
  cidr       = "192.168.199.0/24"
}

resource "vkcs_dc_router" "main_dc_router" {
  availability_zone = "GZ1"
  flavor            = "standard"
  name              = "main_dc_router"
  description       = "used as public gateway"
}

# Connect internet to the router
resource "vkcs_dc_interface" "dc_interface_internet" {
  name         = "interface-for-internet"
  dc_router_id = vkcs_dc_router.main_dc_router.id
  network_id   = data.vkcs_networking_network.internet_sprut.id
}

# Connect networks to the router
resource "vkcs_dc_interface" "main_dc_router_private_net" {
  name         = "dc-interface-for-subnet-sprut"
  dc_router_id = vkcs_dc_router.main_dc_router.id
  network_id   = vkcs_networking_network.app.id
  subnet_id    = vkcs_networking_subnet.app.id
  ip_address   = vkcs_networking_subnet.app.gateway_ip
}

resource "vkcs_dc_ip_port_forwarding" "dc-ip-port-forwarding" {
  for_each = {for i in vkcs_compute_instance.instance : i.name => i}
  dc_interface_id = vkcs_dc_interface.dc_interface_internet.id
  name            = "lab_dnat_ssh_rule_${each.key}"
  protocol        = "tcp"
  port            = var.port_range_start+split(".", each.value.access_ip_v4)[3]
  to_port         = 22
  to_destination  = each.value.access_ip_v4
}
