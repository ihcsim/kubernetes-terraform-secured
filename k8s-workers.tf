resource "digitalocean_droplet" "k8s_workers" {
  count = "${var.k8s_workers_count}"

  name = "${format("k8s-worker-%02d", count.index)}"
  image = "${var.coreos_image}"
  region = "${var.droplet_region}"
  size = "2GB"
  private_networking = "true"
  ssh_keys = ["${var.droplet_private_key_id}"]
  user_data = "${element(data.ct_config.k8s_workers.*.rendered, count.index)}"

  connection {
    user = "${var.droplet_ssh_user}"
    private_key = "${file(var.droplet_private_key_file)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p ${var.k8s_bin_home} ${var.k8s_lib_kubelet_home} ${var.k8s_lib_kube_proxy_home}",
      "sudo chown -R core ${var.k8s_home}",
      "wget -P ${var.k8s_bin_home} https://storage.googleapis.com/kubernetes-release/release/${var.k8s_version}/bin/linux/amd64/kubelet",
      "wget -P ${var.k8s_bin_home} https://storage.googleapis.com/kubernetes-release/release/${var.k8s_version}/bin/linux/amd64/kube-proxy",
      "wget -P ${var.k8s_bin_home} https://storage.googleapis.com/kubernetes-release/release/${var.k8s_version}/bin/linux/amd64/kubectl",
      "chmod +x ${var.k8s_bin_home}/*"
    ]
  }

  provisioner "file" {
    content = "${element(data.template_file.kubelet_kubeconfig.*.rendered, count.index)}"
    destination = "${var.k8s_lib_kubelet_home}/kubeconfig"
  }

  provisioner "file" {
    content = "${data.template_file.kube_proxy_kubeconfig.rendered}"
    destination = "${var.k8s_lib_kube_proxy_home}/kubeconfig"
  }

  provisioner "file" {
    content = "${data.template_file.kube_proxy_config.rendered}"
    destination = "${var.k8s_lib_kube_proxy_home}/config"
  }
}

resource "null_resource" "k8s_workers_tls" {
  count = "${var.k8s_workers_count}"

  triggers {
    droplet = "${join(",", digitalocean_droplet.k8s_workers.*.id)}"
  }

  connection {
    user = "${var.droplet_ssh_user}"
    private_key = "${file(var.droplet_private_key_file)}"
    host = "${element(digitalocean_droplet.k8s_workers.*.ipv4_address, count.index)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p ${var.droplet_tls_certs_home}/${var.droplet_domain}/kubelet ${var.droplet_tls_certs_home}/${var.droplet_domain}/kube-proxy",
      "sudo chown -R ${var.droplet_ssh_user} ${var.droplet_tls_certs_home}/${var.droplet_domain}"
    ]
  }

  provisioner "file" {
    content = "${tls_self_signed_cert.cacert.cert_pem}"
    destination = "${var.droplet_tls_certs_home}/${var.droplet_domain}/${var.tls_cacert_file}"
  }

  provisioner "file" {
    content = "${element(tls_locally_signed_cert.kubelet.*.cert_pem, count.index)}"
    destination = "${var.droplet_tls_certs_home}/${var.droplet_domain}/kubelet/${var.tls_cert_file}"
  }

  provisioner "file" {
    content = "${element(tls_private_key.kubelet.*.private_key_pem, count.index)}"
    destination = "${var.droplet_tls_certs_home}/${var.droplet_domain}/kubelet/${var.tls_key_file}"
  }

  provisioner "file" {
    content = "${tls_locally_signed_cert.kube_proxy.cert_pem}"
    destination = "${var.droplet_tls_certs_home}/${var.droplet_domain}/kube-proxy/${var.tls_cert_file}"
  }

  provisioner "file" {
    content = "${tls_private_key.kube_proxy.private_key_pem}"
    destination = "${var.droplet_tls_certs_home}/${var.droplet_domain}/kube-proxy/${var.tls_key_file}"
  }
}

data "ct_config" "k8s_workers" {
  count = "${var.k8s_workers_count}"

  platform = "digitalocean"
  content = "${element(data.template_file.k8s_workers_config.*.rendered, count.index)}"
}

data "template_file" "k8s_workers_config" {
  count = "${var.k8s_workers_count}"

  template = "${file("${path.module}/k8s/workers/config.yaml")}"

  vars {
    cluster_dns_ip = "${var.k8s_cluster_dns_ip}"
    cluster_domain = "${var.k8s_cluster_domain}"

    lib_home = "${var.k8s_lib_home}"
    kubelet_kubeconfig = "${var.k8s_lib_kubelet_home}/kubeconfig"
    kube_proxy_config_file = "${var.k8s_lib_kube_proxy_home}/config"
    kube_proxy_config = "${jsonencode(data.template_file.kube_proxy_config.rendered)}"

    etcd_client_port = "${var.etcd_client_port}"

    cacert_file = "${var.droplet_tls_certs_home}/${var.droplet_domain}/${var.tls_cacert_file}"
    cert_file = "${var.droplet_tls_certs_home}/${var.droplet_domain}/kubelet/${var.tls_cert_file}"
    key_file = "${var.droplet_tls_certs_home}/${var.droplet_domain}/kubelet/${var.tls_key_file}"

    maintenance_window_start = "${var.droplet_maintenance_window_start}"
    maintenance_window_length = "${var.droplet_maintenance_window_length}"
    update_channel = "${var.droplet_update_channel}"
  }
}

data "template_file" "kubelet_kubeconfig" {
  count = "${var.k8s_workers_count}"
  template = "${file("${path.module}/k8s/workers/kubeconfig")}"

  vars {
    apiserver_endpoint = "${format("https://%s:%s", digitalocean_droplet.k8s_masters.0.ipv4_address_private, var.k8s_apiserver_secure_port)}"

    cacert_file = "${var.droplet_tls_certs_home}/${var.droplet_domain}/${var.tls_cacert_file}"
    client_cert_file = "${var.droplet_tls_certs_home}/${var.droplet_domain}/kubelet/${var.tls_cert_file}"
    client_key_file = "${var.droplet_tls_certs_home}/${var.droplet_domain}/kubelet/${var.tls_key_file}"

    cluster_name = "${var.k8s_cluster_name}"
    username = "${format("k8s-worker-%02d", count.index)}"
  }
}

data "template_file" "kube_proxy_kubeconfig" {
  template = "${file("${path.module}/k8s/workers/kubeconfig")}"

  vars {
    apiserver_endpoint = "${format("https://%s:%s", digitalocean_droplet.k8s_masters.0.ipv4_address_private, var.k8s_apiserver_secure_port)}"

    cacert_file = "${var.droplet_tls_certs_home}/${var.droplet_domain}/${var.tls_cacert_file}"
    client_cert_file = "${var.droplet_tls_certs_home}/${var.droplet_domain}/kube-proxy/${var.tls_cert_file}"
    client_key_file = "${var.droplet_tls_certs_home}/${var.droplet_domain}/kube-proxy/${var.tls_key_file}"

    cluster_name = "${var.k8s_cluster_name}"
    username = "kube-proxy"
  }
}

data "template_file" "kube_proxy_config" {
  template = "${file("${path.module}/k8s/workers/kube-proxy-config")}"

  vars {
    cluster_cidr = "${var.k8s_cluster_cidr}"
    kube_proxy_kubeconfig = "${var.k8s_lib_kube_proxy_home}/kubeconfig"
  }
}

resource "tls_private_key" "kubelet" {
  count = "${var.k8s_workers_count}"

  algorithm = "RSA"
  rsa_bits = 4096
}

resource "tls_cert_request" "kubelet" {
  count = "${var.k8s_workers_count}"

  key_algorithm = "${element(tls_private_key.kubelet.*.algorithm, count.index)}"
  private_key_pem = "${element(tls_private_key.kubelet.*.private_key_pem, count.index)}"

  subject {
    common_name = "${var.tls_workers_cert_subject_common_name}:${element(digitalocean_droplet.k8s_workers.*.name, count.index)}"
    organization = "${var.tls_workers_cert_subject_organization}"
    organizational_unit = "${var.tls_cert_subject_organizational_unit}"
    street_address = ["${var.tls_cert_subject_street_address}"]
    locality = "${var.tls_cert_subject_locality}"
    province = "${var.tls_cert_subject_province}"
    country = "${var.tls_cert_subject_country}"
    postal_code = "${var.tls_cert_subject_postal_code}"
  }

  ip_addresses = [
    "${element(digitalocean_droplet.k8s_workers.*.ipv4_address_private, count.index)}"
  ]
}

resource "tls_locally_signed_cert" "kubelet" {
  count = "${var.k8s_workers_count}"

  cert_request_pem = "${element(tls_cert_request.kubelet.*.cert_request_pem, count.index)}"
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

resource "tls_private_key" "kube_proxy" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "tls_cert_request" "kube_proxy" {
  key_algorithm = "${tls_private_key.kube_proxy.algorithm}"
  private_key_pem = "${tls_private_key.kube_proxy.private_key_pem}"

  subject {
    common_name = "${var.tls_kube_proxy_cert_subject_common_name}"
    organization = "${var.tls_kube_proxy_cert_subject_organization}"
    organizational_unit = "${var.tls_cert_subject_organizational_unit}"
    street_address = ["${var.tls_cert_subject_street_address}"]
    locality = "${var.tls_cert_subject_locality}"
    province = "${var.tls_cert_subject_province}"
    country = "${var.tls_cert_subject_country}"
    postal_code = "${var.tls_cert_subject_postal_code}"
  }
}

resource "tls_locally_signed_cert" "kube_proxy" {
  cert_request_pem = "${tls_cert_request.kube_proxy.cert_request_pem}"
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
