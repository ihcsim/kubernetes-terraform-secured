resource "digitalocean_droplet" "k8s_masters" {
  count = "${var.k8s_apiserver_count}"

  name = "${format("k8s-master-%02d", count.index)}"
  image = "${var.coreos_image}"
  region = "${var.droplet_region}"
  size = "2GB"
  private_networking = "true"
  ssh_keys = ["${var.droplet_private_key_id}"]
  user_data = "${data.ct_config.k8s_master.rendered}"

  connection {
    user = "${var.droplet_ssh_user}"
    private_key = "${file(var.droplet_private_key_file)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p ${var.k8s_bin_home}",
      "sudo chown -R core ${var.k8s_home}",
      "wget -p ${var.k8s_bin_home} https://storage.googleapis.com/kubernetes-release/release/${var.k8s_version}/bin/linux/amd64/kube-aggregator",
      "wget -P ${var.k8s_bin_home} https://storage.googleapis.com/kubernetes-release/release/${var.k8s_version}/bin/linux/amd64/kube-apiserver",
      "wget -P ${var.k8s_bin_home} https://storage.googleapis.com/kubernetes-release/release/${var.k8s_version}/bin/linux/amd64/kube-controller-manager",
      "wget -P ${var.k8s_bin_home} https://storage.googleapis.com/kubernetes-release/release/${var.k8s_version}/bin/linux/amd64/kube-scheduler",
      "wget -P ${var.k8s_bin_home} https://storage.googleapis.com/kubernetes-release/release/${var.k8s_version}/bin/linux/amd64/kubefed",
      "wget -P ${var.k8s_bin_home} https://storage.googleapis.com/kubernetes-release/release/${var.k8s_version}/bin/linux/amd64/kubectl",
      "wget -P ${var.k8s_bin_home} https://storage.googleapis.com/kubernetes-release/release/${var.k8s_version}/bin/linux/amd64/cloud-controller-manager",
      "wget -P ${var.k8s_bin_home} https://storage.googleapis.com/kubernetes-release/release/${var.k8s_version}/bin/linux/amd64/apiextensions-apiserver",
      "chmod +x ${var.k8s_bin_home}/*"
    ]
  }

  connection {
    user = "${var.droplet_ssh_user}"
    private_key = "${file(var.droplet_private_key_file)}"
  }

  provisioner "file" {
    content = "${data.template_file.k8s_apiserver_encryption_config.rendered}"
    destination = "${var.k8s_home}/encryption.yaml"
  }

  provisioner "file" {
    content = "${data.template_file.k8s_apiserver_token_file.rendered}"
    destination = "/opt/k8s/token.csv"
  }
}

resource "null_resource" "k8s_masters_tls" {
  count = "${var.k8s_apiserver_count}"

  triggers {
    droplet = "${join(",", digitalocean_droplet.k8s_masters.*.id)}"
  }

  connection {
    user = "${var.droplet_ssh_user}"
    private_key = "${file(var.droplet_private_key_file)}"
    host = "${element(digitalocean_droplet.k8s_masters.*.ipv4_address, count.index)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p ${var.droplet_tls_certs_home}/${var.droplet_domain}",
      "sudo chown -R ${var.droplet_ssh_user} ${var.droplet_tls_certs_home}/${var.droplet_domain}"
    ]
  }

  provisioner "file" {
    content = "${tls_self_signed_cert.cacert.cert_pem}"
    destination = "${var.droplet_tls_certs_home}/${var.droplet_domain}/${var.tls_cacert_file}"
  }

  provisioner "file" {
    content = "${tls_private_key.cakey.private_key_pem}"
    destination = "${var.droplet_tls_certs_home}/${var.droplet_domain}/${var.tls_cakey_file}"
  }

  provisioner "file" {
    content = "${element(tls_locally_signed_cert.kube_apiserver.*.cert_pem, count.index)}"
    destination = "${var.droplet_tls_certs_home}/${var.droplet_domain}/${var.tls_cert_file}"
  }

  provisioner "file" {
    content = "${element(tls_private_key.kube_apiserver.*.private_key_pem, count.index)}"
    destination = "${var.droplet_tls_certs_home}/${var.droplet_domain}/${var.tls_key_file}"
  }
}

data "ct_config" "k8s_master" {
  platform = "digitalocean"
  content = "${data.template_file.k8s_master_config.rendered}"
}

data "template_file" "k8s_master_config" {
  template = "${file("${path.module}/k8s/master/config.yaml")}"

  vars {
    apiserver_count = "${var.k8s_apiserver_count}"
    apiserver_encryption_config_file = "${var.k8s_home}/encryption.yaml"
    apiserver_insecure_port = "${var.k8s_apiserver_insecure_port}"
    apiserver_secure_port = "${var.k8s_apiserver_secure_port}"

    etcd_endpoints = "${join(",", formatlist("https://%s:%s", digitalocean_droplet.etcd.*.ipv4_address_private, var.etcd_client_port))}"
    etcd_client_port = "${var.etcd_client_port}"

    dns_server = "${digitalocean_droplet.coredns.ipv4_address_private}"
    domain = "${var.droplet_domain}"

    cacert_file = "${var.droplet_tls_certs_home}/${var.droplet_domain}/${var.tls_cacert_file}"
    cakey_file = "${var.droplet_tls_certs_home}/${var.droplet_domain}/${var.tls_cakey_file}"
    cert_file = "${var.droplet_tls_certs_home}/${var.droplet_domain}/${var.tls_cert_file}"
    key_file = "${var.droplet_tls_certs_home}/${var.droplet_domain}/${var.tls_key_file}"

    cluster_name = "${var.k8s_cluster_name}"
    cluster_cidr = "${var.k8s_cluster_cidr}"

    service_cluster_ip_range = "${var.k8s_service_cluster_ip_range}"
    service_node_port_range = "${var.k8s_service_node_port_range}"

    maintenance_window_start = "${var.droplet_maintenance_window_start}"
    maintenance_window_length = "${var.droplet_maintenance_window_length}"
    update_channel = "${var.droplet_update_channel}"
  }
}

data "template_file" "k8s_apiserver_encryption_config" {
  template = "${file("${path.module}/k8s/master/encryption.yaml")}"

  vars {
    encryption_key = "${var.k8s_apiserver_encryption_key}"
  }
}

data "template_file" "k8s_apiserver_token_file" {
  template = "${file("${path.module}/k8s/master/token.csv")}"

  vars {
    client_token = ""
  }
}

resource "tls_private_key" "kube_apiserver" {
  count = "${var.k8s_apiserver_count}"

  algorithm = "RSA"
  rsa_bits = 4096
}

resource "tls_cert_request" "kube_apiserver" {
  count = "${var.k8s_apiserver_count}"

  key_algorithm = "${element(tls_private_key.kube_apiserver.*.algorithm, count.index)}"
  private_key_pem = "${element(tls_private_key.kube_apiserver.*.private_key_pem, count.index)}"

  ip_addresses = [
    "${element(digitalocean_droplet.k8s_masters.*.ipv4_address_private, count.index)}",
    "${element(digitalocean_droplet.k8s_masters.*.ipv4_address, count.index)}"
  ]

  dns_names = [
    "${element(digitalocean_droplet.k8s_masters.*.name, count.index)}",
    "${element(digitalocean_droplet.k8s_masters.*.name, count.index)}.${var.droplet_domain}"
  ]

  subject {
    common_name = "${var.tls_kube_apiserver_cert_subject_common_name}"
    organization = "${var.tls_kube_apiserver_cert_subject_organization}"
    organizational_unit = "${var.tls_cert_subject_organizational_unit}"
    street_address = ["${var.tls_cert_subject_street_address}"]
    locality = "${var.tls_cert_subject_locality}"
    province = "${var.tls_cert_subject_province}"
    country = "${var.tls_cert_subject_country}"
    postal_code = "${var.tls_cert_subject_postal_code}"
  }
}

resource "tls_locally_signed_cert" "kube_apiserver" {
  count = "${var.k8s_apiserver_count}"

  cert_request_pem = "${element(tls_cert_request.kube_apiserver.*.cert_request_pem, count.index)}"
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
