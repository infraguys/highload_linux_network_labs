resource "vkcs_compute_instance" "instance" {
  count     = var.instances_number
  name      = "instance-${count.index}"
  flavor_id = data.vkcs_compute_flavor.basic.id

  block_device {
    source_type      = "image"
    uuid             = data.vkcs_images_image.debian.id
    destination_type = "volume"
    volume_size      = 5
    delete_on_termination = true
  }

  security_group_ids = [
    vkcs_networking_secgroup.lab_main.id
  ]

  network {
    uuid = vkcs_networking_network.app.id
  }

  depends_on = [
    vkcs_dc_router.main_dc_router
  ]

  key_pair = vkcs_compute_keypair.infraguys_key.id

  admin_pass = random_password.password[count.index].result

  user_data = file("${path.module}/artifacts/user_data.sh")
}


resource "ssh_resource" "always_run" {
  for_each = {for idx, val in vkcs_compute_instance.instance : idx => val}
  triggers = {
    always_run = "${timestamp()}"
  }

  host         = vkcs_dc_interface.dc_interface_internet.ip_address
  user         = var.image_user
  private_key  = file("~/.ssh/infraguys")
  port         = var.port_range_start+split(".", each.value.access_ip_v4)[3]

  commands = [
     "ls | grep lab",
     "cd ./highload_linux_network_labs && git pull && cd -",
     "cp -a ./highload_linux_network_labs/labs/* ./",
     " sudo usermod --password $(echo  ${random_password.password[each.key].result} | openssl passwd -1 -stdin) debian"
  ]

  timeout     = "15s"
  retry_delay = "5s"
}
