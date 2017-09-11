resource "digitalocean_droplet" "skydns" {
  name = "skydns"
  image = "${var.coreos_image}"
  region = "${var.droplet_region}"
  size = "1GB"
  private_networking = "true"
  ssh_keys = ["${var.droplet_private_key_id}"]
  user_data = "${data.template_file.skydns_cloud_config.rendered}"

  connection {
    user = "${var.droplet_ssh_user}"
    private_key = "${file(var.droplet_private_key_file)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p ${var.skydns_home} ${var.skydns_bin_home} ${var.skydns_unit_files_home}",
      "sudo chown -R core:core ${var.skydns_home}",
      "wget -P ${var.skydns_bin_home} https://s3-us-west-2.amazonaws.com/kubernetes-terraform-secured/skydns-${var.skydns_version}",
      "chmod +x ${var.skydns_bin_home}/*",
      "sudo systemctl restart systemd-resolved"
    ]
  }

  provisioner "file" {
    content = "${data.template_file.unit_file_skydns.rendered}"
    destination = "${var.skydns_unit_files_home}/skydns.service"
  }
}

resource "null_resource" "skydns_tls" {
  triggers {
    droplet_id = "${digitalocean_droplet.skydns.id}"
    cert = "${tls_locally_signed_cert.skydns_cert.cert_pem}"
  }

  connection {
    user = "${var.droplet_ssh_user}"
    private_key = "${file(var.droplet_private_key_file)}"
    host = "${digitalocean_droplet.skydns.ipv4_address}"
  }

  provisioner "remote-exec" {
    inline = <<EOF
sudo mkdir -p ${var.skydns_tls_home}
sudo chown core:core ${var.skydns_tls_home}

sudo cat <<CERT > ${var.skydns_cert_file}
${tls_locally_signed_cert.skydns_cert.cert_pem}
CERT

sudo cat <<KEY > ${var.skydns_key_file}
${tls_private_key.skydns_key.private_key_pem}
KEY

sudo cat <<CERT > ${var.skydns_ca_file}
${tls_self_signed_cert.cacert.cert_pem}
CERT

sudo systemctl enable ${var.skydns_unit_files_home}/*
sudo systemctl start skydns
EOF
  }
}

data "template_file" "skydns_cloud_config" {
  template = "${file("${path.module}/dns/cloud-config")}"

  vars {
    ca_file = "${var.skydns_ca_file}"
    cert_file = "${var.skydns_cert_file}"
    domain = "${var.droplet_domain}"
    etcd_endpoints  = "${join(",", formatlist("https://%s:%s", digitalocean_droplet.etcd.*.ipv4_address_private, var.etcd_client_port))}"
    fleet_agent_ttl = "${var.fleet_agent_ttl}"
    fleet_etcd_request_timeout = "${var.fleet_etcd_request_timeout}"
    key_file = "${var.skydns_key_file}"
    resolv_file = "${var.droplet_resolv_file}"
  }
}

data "template_file" "unit_file_skydns" {
  template = "${file("${path.module}/dns/unit-files/skydns.service")}"

  vars {
    etcd_endpoints = "${join(",", formatlist("https://%s:%s", digitalocean_droplet.etcd.*.ipv4_address_private, var.etcd_client_port))}"
    ca_file = "${var.skydns_ca_file}"
    cert_file = "${var.skydns_cert_file}"
    domain = "${var.droplet_domain}"
    key_file = "${var.skydns_key_file}"
    service_key_path = "${var.skydns_domain_key_path}/skydns"
    service_name = "skydns.${var.droplet_domain}"
    skydns_version = "${var.skydns_version}"
  }
}

resource "tls_private_key" "skydns_key" {
  algorithm = "RSA"
  rsa_bits = 2048
}

resource "tls_cert_request" "skydns_csr" {
  key_algorithm = "${tls_private_key.skydns_key.algorithm}"
  private_key_pem = "${tls_private_key.skydns_key.private_key_pem}"
  subject {
    common_name = "${var.tls_skydns_cert_subject_common_name}"
    organization = "${var.tls_skydns_cert_subject_organization}"
    organizational_unit = "${var.tls_cert_subject_organizational_unit}"
    street_address = ["${var.tls_cert_subject_street_address}"]
    locality = "${var.tls_cert_subject_locality}"
    province = "${var.tls_cert_subject_province}"
    country = "${var.tls_cert_subject_country}"
    postal_code = "${var.tls_cert_subject_postal_code}"
  }

  ip_addresses = [
    "${digitalocean_droplet.skydns.ipv4_address}",
    "${digitalocean_droplet.skydns.ipv4_address_private}"
  ]

  dns_names = [
    "${digitalocean_droplet.skydns.name}",
    "${digitalocean_droplet.skydns.name}.${var.droplet_domain}",
  ]
}

resource "tls_locally_signed_cert" "skydns_cert" {
  cert_request_pem = "${tls_cert_request.skydns_csr.cert_request_pem}"
  ca_key_algorithm = "${tls_private_key.cakey.algorithm}"
  ca_private_key_pem = "${tls_private_key.cakey.private_key_pem}"
  ca_cert_pem = "${tls_self_signed_cert.cacert.cert_pem}"
  validity_period_hours = "${var.tls_cert_validity_period_hours}"
  allowed_uses = [
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
  early_renewal_hours = "${var.tls_cert_early_renewal_hours}"
}
