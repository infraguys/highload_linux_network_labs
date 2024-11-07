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

  user_data =  <<EOF
#!/bin/bash

echo "[TASK 1] Enable ssh password authentication"
sed -i 's/^PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config
systemctl reload sshd

echo "[TASK 2] Prepare packages"
apt update
apt install docker.io openvswitch-switch -y

echo "[TASK 3] Prepare docker"
usermod -a -G docker debian

echo "[TASK 4] Prefetch docker images"
docker image pull ghcr.io/infraguys/debian_lab

echo "[TASK 5] Clone git repo with labs"
cd /home/debian
git clone https://github.com/infraguys/highload_linux_network_labs.git
chown debian:debian -R ./highload_linux_network_labs
cd -

  EOF
}


# resource "ssh_resource" "always_run" {
#   for_each = {for i in vkcs_compute_instance.instance : i.name => i}
#   triggers = {
#     always_run = "${timestamp()}"
#   }

#   host         = vkcs_dc_interface.dc_interface_internet.ip_address
#   user         = var.image_user
#   private_key  = file("~/.ssh/infraguys")
#   port         = var.port_range_start+split(".", each.value.access_ip_v4)[3]

#   commands = [
#      "ls | grep lab"
#   ]

#   timeout     = "15s"
#   retry_delay = "5s"
# }
