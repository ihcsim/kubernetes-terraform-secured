resource "digitalocean_droplet" "coredns" {
  name = "coredns"
  image = "${var.coreos_image}"
  region = "${var.droplet_region}"
  size = "1GB"
  private_networking = "true"
  ssh_keys = ["${var.droplet_private_key_id}"]
  user_data = "${data.ct_config.coredns.rendered}"

  lifecycle {
    create_before_destroy = true
  }

  connection {
    user = "${var.droplet_ssh_user}"
    private_key = "${file(var.droplet_private_key_file)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /opt/coredns/zones",
      "sudo chown -R ${var.droplet_ssh_user} /opt/coredns"
    ]
  }

  provisioner "file" {
    content = "${data.template_file.coredns_corefile.rendered}"
    destination = "/opt/coredns/Corefile"
  }

  provisioner "file" {
    content = "${data.template_file.coredns_zonefile.rendered}"
    destination = "/opt/coredns/zones/${var.droplet_domain}"
  }
}

resource "null_resource" "coredns_zonefile_records" {
  triggers {
    etcd = "${join(",", digitalocean_droplet.etcd.*.ipv4_address_private)}"
    k8s_masters = "${join(",", digitalocean_droplet.k8s_masters.*.ipv4_address_private)}"
    k8s_workers = "${join(",", digitalocean_droplet.k8s_workers.*.ipv4_address_private)}"
  }

  connection {
    user = "${var.droplet_ssh_user}"
    private_key = "${file(var.droplet_private_key_file)}"
    host = "${digitalocean_droplet.coredns.ipv4_address}"
  }

  provisioner "remote-exec" {
    inline = [<<CMD
cat <<EOF >> /opt/coredns/zones/${var.droplet_domain}
${format("%s IN A %s", digitalocean_droplet.coredns.name, digitalocean_droplet.coredns.ipv4_address_private)}

${join("\n", formatlist("%s IN A %s", digitalocean_droplet.etcd.*.name, digitalocean_droplet.etcd.*.ipv4_address_private))}

${join("\n", formatlist("%s IN A %s", digitalocean_droplet.k8s_masters.*.name, digitalocean_droplet.k8s_masters.*.ipv4_address_private))}

${join("\n", formatlist("%s IN A %s", digitalocean_droplet.k8s_workers.*.name, digitalocean_droplet.k8s_workers.*.ipv4_address_private))}
EOF

sudo systemctl restart coredns
    CMD
    ]
  }
}

data "ct_config" "coredns" {
  platform = "digitalocean"
  content = "${data.template_file.coredns_config.rendered}"
}

data "template_file" "coredns_config" {
  template = "${file("${path.module}/dns/config.yaml")}"

  vars {
    dns_server = "127.0.0.1"
    domain = "${var.droplet_domain}"
    tag = "${var.coredns_version}"
  }
}

data "template_file" "coredns_corefile" {
  template = "${file("${path.module}/dns/Corefile")}"

  vars {
    domain = "${var.droplet_domain}"
  }
}

data "template_file" "coredns_zonefile" {
  template = "${file("${path.module}/dns/zone")}"

  vars {
    domain = "${var.droplet_domain}"
  }
}
