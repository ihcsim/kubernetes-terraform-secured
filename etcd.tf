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

  lifecycle {
    create_before_destroy = true
  }
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
      "sudo mkdir -p ${var.droplet_tls_certs_home}/${var.droplet_domain}",
      "sudo chown -R ${var.droplet_ssh_user} ${var.droplet_tls_certs_home}/${var.droplet_domain}"
    ]
  }

  provisioner "file" {
    content = "${element(tls_locally_signed_cert.etcd_cert.*.cert_pem, count.index)}"
    destination = "${var.droplet_tls_certs_home}/${var.droplet_domain}/${var.tls_cert_file}"
  }

  provisioner "file" {
    content = "${element(tls_private_key.etcd_key.*.private_key_pem, count.index)}"
    destination = "${var.droplet_tls_certs_home}/${var.droplet_domain}/${var.tls_key_file}"
  }
}

resource "digitalocean_volume" "etcd_data" {
  count = "${var.etcd_count}"

  name = "${format("etcd-%02d-data", count.index)}"
  region = "${var.droplet_region}"
  size = 10
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
    data_dir = "${var.etcd_data_dir}"

    etcd_client_port = "${var.etcd_client_port}"
    etcd_peer_port = "${var.etcd_peer_port}"
    etcd_heartbeat_interval = "${var.etcd_heartbeat_interval}"
    etcd_election_timeout = "${var.etcd_election_timeout}"
    etcd_initial_cluster = "${join(",", formatlist("%s=https://%s.${var.droplet_domain}:%s", list("etcd-00", "etcd-01", "etcd-02"), list("etcd-00", "etcd-01", "etcd-02"), var.etcd_peer_port))}"

    domain = "${var.droplet_domain}"
    dns_server = "${digitalocean_droplet.coredns.ipv4_address_private}"

    cacert = "${jsonencode(tls_self_signed_cert.cacert.cert_pem)}"
    cacert_file = "${var.droplet_tls_certs_home}/${var.droplet_domain}/${var.tls_cacert_file}"
    cert_file = "${var.droplet_tls_certs_home}/${var.droplet_domain}/${var.tls_cert_file}"
    key_file = "${var.droplet_tls_certs_home}/${var.droplet_domain}/${var.tls_key_file}"

    device_path = "/dev/disk/by-id/scsi-0DO_Volume_${format("etcd-%02d-data", count.index)}"

    maintenance_window_start = "${var.droplet_maintenance_window_start}"
    maintenance_window_length = "${var.droplet_maintenance_window_length}"
    update_channel = "${var.droplet_update_channel}"
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

  dns_names = [
    "${element(digitalocean_droplet.etcd.*.name, count.index)}",
    "${element(digitalocean_droplet.etcd.*.name, count.index)}.${var.droplet_domain}",
  ]

  subject = {
    common_name = "${var.tls_etcd_cert_subject_common_name}"
    organization = "${var.tls_etcd_cert_subject_organization}"
    organizational_unit = "${var.tls_cert_subject_organizational_unit}"
    street_address = ["${var.tls_cert_subject_street_address}"]
    locality = "${var.tls_cert_subject_locality}"
    province = "${var.tls_cert_subject_province}"
    country = "${var.tls_cert_subject_country}"
    postal_code = "${var.tls_cert_subject_postal_code}"
  }
}

resource "tls_locally_signed_cert" "etcd_cert" {
  count = "${var.etcd_count}"

  cert_request_pem = "${element(tls_cert_request.etcd_csr.*.cert_request_pem, count.index)}"
  ca_private_key_pem = "${tls_private_key.cakey.private_key_pem}"
  ca_key_algorithm = "${tls_private_key.cakey.algorithm}"
  ca_cert_pem = "${tls_self_signed_cert.cacert.cert_pem}"

  validity_period_hours = "${var.tls_cert_validity_period_hours}"
  early_renewal_hours = "${var.tls_cert_early_renewal_hours}"

  allowed_uses = [
    "key_encipherment",
    "server_auth",
    "client_auth"
  ]
}
