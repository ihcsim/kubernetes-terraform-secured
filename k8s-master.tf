resource "digitalocean_droplet" "k8s_master" {
  name = "k8s-master"
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
}

resource "null_resource" "k8s_master_tls" {
  triggers {
    droplet = "digitalocean_droplet.k8s_master.id"
  }

  connection {
    user = "${var.droplet_ssh_user}"
    private_key = "${file(var.droplet_private_key_file)}"
    host = "${digitalocean_droplet.k8s_master.ipv4_address}"
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
    content = "${tls_locally_signed_cert.kube_apiserver.cert_pem}"
    destination = "${var.droplet_tls_certs_home}/${var.droplet_domain}/${var.tls_cert_file}"
  }

  provisioner "file" {
    content = "${tls_private_key.kube_apiserver.private_key_pem}"
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
    apiserver_encryption_config_file = "${var.k8s_apiserver_encryption_config_file}"
    apiserver_insecure_port = "${var.k8s_apiserver_insecure_port}"
    apiserver_secure_port = "${var.k8s_apiserver_secure_port}"

    etcd_endpoints = "${join(",", formatlist("https://%s:%s", digitalocean_droplet.etcd.*.ipv4_address_private, var.etcd_client_port))}"

    cacert_file = "${var.droplet_tls_certs_home}/${var.droplet_domain}/${var.tls_cacert_file}"
    cakey_file = "${var.droplet_tls_certs_home}/${var.droplet_domain}/${var.tls_cakey_file}"
    cert_file = "${var.droplet_tls_certs_home}/${var.droplet_domain}/${var.tls_cert_file}"
    key_file = "${var.droplet_tls_certs_home}/${var.droplet_domain}/${var.tls_key_file}"

    cluster_name = "${var.k8s_cluster_name}"
    cluster_cidr = "${var.k8s_cluster_cidr}"

    service_cluster_ip_range = "${var.k8s_service_cluster_ip_range}"
    service_node_port_range = "${var.k8s_service_node_port_range}"
  }
}

resource "tls_private_key" "kube_apiserver" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "tls_cert_request" "kube_apiserver" {
  key_algorithm = "${tls_private_key.kube_apiserver.algorithm}"
  private_key_pem = "${tls_private_key.kube_apiserver.private_key_pem}"

  ip_addresses = [
    "${digitalocean_droplet.k8s_master.ipv4_address_private}",
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
  cert_request_pem = "${tls_cert_request.kube_apiserver.cert_request_pem}"
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

resource "tls_private_key" "k8s_admin_client" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "tls_cert_request" "k8s_admin_client" {
  key_algorithm = "${tls_private_key.k8s_admin_client.algorithm}"
  private_key_pem = "${tls_private_key.k8s_admin_client.private_key_pem}"

  subject {
    common_name = "${var.tls_client_cert_subject_common_name}"
    organization = "${var.tls_client_cert_subject_organization}"
    organizational_unit = "${var.tls_cert_subject_organizational_unit}"
    street_address = ["${var.tls_cert_subject_street_address}"]
    locality = "${var.tls_cert_subject_locality}"
    province = "${var.tls_cert_subject_province}"
    country = "${var.tls_cert_subject_country}"
    postal_code = "${var.tls_cert_subject_postal_code}"
  }
}

resource "tls_locally_signed_cert" "k8s_admin_client" {
  cert_request_pem = "${tls_cert_request.k8s_admin_client.cert_request_pem}"
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