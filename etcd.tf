output "etcd" {
  value = "${formatlist("https://%s:%s", digitalocean_droplet.etcd.*.ipv4_address, var.etcd_client_port)}"
}

resource "digitalocean_droplet" "etcd" {
  name = "${format("etcd-%02d", count.index)}"
  image = "${var.coreos_image}"
  region = "${var.droplet_region}"
  size = "1GB"
  count = "${var.etcd_count}"
  private_networking = "true"
  ssh_keys = ["${var.droplet_private_key_id}"]
  user_data = "${data.template_file.etcd_cloud_config.rendered}"
}

resource "null_resource" "etcd_tls" {
  triggers {
    etcd_droplets_ids = "${join(",", digitalocean_droplet.etcd.*.id)}"
    cert = "${tls_locally_signed_cert.etcd_cert.cert_pem}"
  }

  count = "${var.etcd_count}"
  connection {
    user = "${var.droplet_ssh_user}"
    private_key = "${file(var.droplet_private_key_file)}"
    host = "${element(digitalocean_droplet.etcd.*.ipv4_address, count.index)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p ${var.etcd_tls_home}",
      "sudo chown core:core ${var.etcd_tls_home}",
      "sudo cat <<EOF > ${var.etcd_cert_file}
${tls_locally_signed_cert.etcd_cert.cert_pem}
EOF",
      "sudo cat <<EOF > ${var.etcd_key_file}
${tls_private_key.etcd_key.private_key_pem}
EOF",
      "sudo cat <<EOF > ${var.etcd_trusted_ca_file}
${tls_self_signed_cert.ca_cert.cert_pem}
EOF",
      "sudo chmod 0644 ${var.etcd_tls_home}/*",
    ]
  }
}

data "template_file" "etcd_cloud_config" {
  template = "${file("${path.module}/etcd/cloud-config")}"

  vars {
    discovery_url = "${var.etcd_discovery_url}"
    etcd_client_port = "${var.etcd_client_port}"
    etcd_peer_port = "${var.etcd_peer_port}"
    etcd_heartbeat_interval = "${var.etcd_heartbeat_interval}"
    etcd_election_timeout = "${var.etcd_election_timeout}"
    etcd_tls_home = "${var.etcd_tls_home}"
    fleet_agent_ttl = "${var.fleet_agent_ttl}"
    fleet_etcd_request_timeout = "${var.fleet_etcd_request_timeout}"
    cert_file = "${var.etcd_cert_file}"
    key_file = "${var.etcd_key_file}"
    trusted_ca_file = "${var.etcd_trusted_ca_file}"
    client_cert_auth = "true"
    peer_client_cert_auth = "true"
  }
}

resource "tls_private_key" "etcd_key" {
  algorithm = "RSA"
  rsa_bits = 2048
}

resource "tls_cert_request" "etcd_csr" {
  key_algorithm = "${tls_private_key.etcd_key.algorithm}"
  private_key_pem = "${tls_private_key.etcd_key.private_key_pem}"
  subject {
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

  ip_addresses = [
    "${digitalocean_droplet.etcd.*.ipv4_address}",
    "${digitalocean_droplet.etcd.*.ipv4_address_private}"
  ]
}

resource "tls_locally_signed_cert" "etcd_cert" {
  cert_request_pem = "${tls_cert_request.etcd_csr.cert_request_pem}"
  ca_key_algorithm = "${tls_private_key.ca_key.algorithm}"
  ca_private_key_pem = "${tls_private_key.ca_key.private_key_pem}"
  ca_cert_pem = "${tls_self_signed_cert.ca_cert.cert_pem}"
  validity_period_hours = "${var.tls_cluster_cert_validity_period_hours}"
  allowed_uses = [
    "key_encipherment",
    "server_auth",
    "client_auth",
    "cert_signing"
  ]
  early_renewal_hours = "${var.tls_cluster_cert_early_renewal_hours}"
}
