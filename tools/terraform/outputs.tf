output "passwords" {
  sensitive = true
  value = random_password.password[*].result
}

output "instance_listing" {
  sensitive = true
  value = {for index, i in vkcs_compute_instance.instance : var.port_range_start+split(".", i.access_ip_v4)[3] => i.admin_pass}
}

output "public_ip" {
  value = vkcs_dc_interface.dc_interface_internet.ip_address
}

output "instance_ports" {
  sensitive = false
  value = {for index, i in vkcs_compute_instance.instance : i.name => var.port_range_start+split(".", i.access_ip_v4)[3]}
}

output "instance_index" {
  sensitive = false
  value = {for index, i in vkcs_compute_instance.instance : index => var.port_range_start+split(".", i.access_ip_v4)[3]}
}
