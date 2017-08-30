resource "digitalocean_droplet" "etcd" {
  count = "${var.etcd_count}"
  name = "${format("etcd-%02d", count.index)}"
  image = "${var.coreos_image}"
  region = "${var.droplet_region}"
  size = "1GB"
  private_networking = "true"
  ssh_keys = ["${var.droplet_private_key_id}"]
  user_data = "${element(data.ct_config.etcd.*.rendered, count.index)}"
  volume_ids = ["${element(digitalocean_volume.etcd_data.*.id, count.index)}"]
}

resource "digitalocean_volume" "etcd_data" {
  count = "${var.etcd_count}"

  name = "${format("etcd-%02d-data", count.index)}"
  region = "${var.droplet_region}"
  size = 10
}

resource "null_resource" "etcd_tls" {
  count = "${var.etcd_count}"

  triggers {
    droplets = "${join(",", digitalocean_droplet.etcd.*.id)}"
  }

  connection {
    user = "${var.droplet_ssh_user}"
    private_key = "${file(var.droplet_private_key_file)}"
    host = "${element(digitalocean_droplet.etcd.*.ipv4_address, count.index)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p ${var.etcd_ssl_home}/${var.droplet_domain}",
      "sudo chown -R ${var.droplet_ssh_user} ${var.etcd_ssl_home}/${var.droplet_domain}"
    ]
  }

  provisioner "file" {
    content = "${element(tls_locally_signed_cert.etcd_cert.*.cert_pem, count.index)}"
    destination = "${var.etcd_ssl_home}/${var.droplet_domain}/${var.etcd_cert_file}"
  }

  provisioner "file" {
    content = "${element(tls_private_key.etcd_key.*.private_key_pem, count.index)}"
    destination = "${var.etcd_ssl_home}/${var.droplet_domain}/${var.etcd_key_file}"
  }
}

data "ct_config" "etcd" {
  count = "${var.etcd_count}"

  platform = "digitalocean"
  content = "${element(data.template_file.etcd_config.*.rendered, count.index)}"
}

data "template_file" "etcd_config" {
  count = "${var.etcd_count}"
  template = "${file("${path.module}/etcd/config.yaml")}"

  vars {
    etcd_version = "${var.etcd_version}"
    discovery_url = "${var.etcd_discovery_url}"
    data_dir = "${var.etcd_data_dir}"

    etcd_client_port = "${var.etcd_client_port}"
    etcd_peer_port = "${var.etcd_peer_port}"
    etcd_heartbeat_interval = "${var.etcd_heartbeat_interval}"
    etcd_election_timeout = "${var.etcd_election_timeout}"

    ca_cert = "${jsonencode(tls_self_signed_cert.ca_cert.cert_pem)}"
    ca_cert_file = "${var.etcd_ssl_home}/${var.droplet_domain}/${var.etcd_trusted_ca_file}"
    cert_file = "${var.etcd_ssl_home}/${var.droplet_domain}/${var.etcd_cert_file}"
    key_file = "${var.etcd_ssl_home}/${var.droplet_domain}/${var.etcd_key_file}"

    device_path = "/dev/disk/by-id/scsi-0DO_Volume_${format("etcd-%02d-data", count.index)}"
  }
}

resource "tls_private_key" "etcd_key" {
  count = "${var.etcd_count}"

  algorithm = "RSA"
  rsa_bits = 4096
}

resource "tls_cert_request" "etcd_csr" {
  count = "${var.etcd_count}"

  key_algorithm = "${element(tls_private_key.etcd_key.*.algorithm, count.index)}"
  private_key_pem = "${element(tls_private_key.etcd_key.*.private_key_pem, count.index)}"

  ip_addresses = [
    "${element(digitalocean_droplet.etcd.*.ipv4_address_private, count.index)}"
  ]

  subject = {
    common_name = "${var.tls_cluster_cert_subject_common_name}"
    organization = "${var.tls_cluster_cert_subject_organization}"
    organizational_unit = "${var.tls_cluster_cert_subject_organizational_unit}"
    street_address = ["${var.tls_cluster_cert_subject_street_address}"]
    locality = "${var.tls_cluster_cert_subject_locality}"
    province = "${var.tls_cluster_cert_subject_province}"
    country = "${var.tls_cluster_cert_subject_country}"
    postal_code = "${var.tls_cluster_cert_subject_postal_code}"
    serial_number = "${var.tls_cluster_cert_subject_serial_number}"
  }
}

resource "tls_locally_signed_cert" "etcd_cert" {
  count = "${var.etcd_count}"

  cert_request_pem = "${element(tls_cert_request.etcd_csr.*.cert_request_pem, count.index)}"
  ca_private_key_pem = "${tls_private_key.ca_key.private_key_pem}"
  ca_key_algorithm = "${tls_private_key.ca_key.algorithm}"
  ca_cert_pem = "${tls_self_signed_cert.ca_cert.cert_pem}"

  validity_period_hours = "${var.tls_cluster_cert_validity_period_hours}"
  early_renewal_hours = "${var.tls_cluster_cert_early_renewal_hours}"
  allowed_uses = [
    "digital_signature",
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}
