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

resource "tls_private_key" "coredns" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "tls_cert_request" "coredns" {
  key_algorithm = "${tls_private_key.coredns.algorithm}"
  private_key_pem = "${tls_private_key.coredns.private_key_pem}"

  ip_addresses = [
    "${digitalocean_droplet.coredns.ipv4_address_private}",
    "${digitalocean_droplet.coredns.ipv4_address}"
  ]

  dns_names = [
    "${digitalocean_droplet.coredns.name}",
    "${digitalocean_droplet.coredns.name}.${var.droplet_domain}"
  ]

  subject {
    common_name = "${var.tls_coredns_cert_subject_common_name}"
    organization = "${var.tls_coredns_cert_subject_organization}"
    organizational_unit = "${var.tls_cert_subject_organizational_unit}"
    street_address = ["${var.tls_cert_subject_street_address}"]
    locality = "${var.tls_cert_subject_locality}"
    province = "${var.tls_cert_subject_province}"
    country = "${var.tls_cert_subject_country}"
    postal_code = "${var.tls_cert_subject_postal_code}"
  }
}

resource "tls_locally_signed_cert" "coredns" {
  cert_request_pem = "${tls_cert_request.coredns.cert_request_pem}"
  ca_key_algorithm = "${tls_private_key.cakey.algorithm}"
  ca_private_key_pem = "${tls_private_key.cakey.private_key_pem}"
  ca_cert_pem = "${tls_self_signed_cert.cacert.cert_pem}"
  validity_period_hours = "${var.tls_cert_validity_period_hours}"
  early_renewal_hours = "${var.tls_cert_early_renewal_hours}"

  allowed_uses = [
    "server_auth",
    "client_auth"
  ]
}
