output "Kubernetes API" {
  value = "${format("https://%s:%s", digitalocean_droplet.k8s_master.ipv4_address, var.k8s_apiserver_secure_port)}"
}

output "Kubernetes Dashboard" {
  value = "${format("https://%s:%s/ui", digitalocean_droplet.k8s_master.ipv4_address, var.k8s_apiserver_secure_port)}"
}

output "Kubernetes Swagger Docs" {
  value = "${format("https://%s:%s/swagger-ui", digitalocean_droplet.k8s_master.ipv4_address, var.k8s_apiserver_secure_port)}"
}

resource "digitalocean_droplet" "k8s_master" {
  name = "k8s-master"
  image = "${var.coreos_image}"
  region = "${var.droplet_region}"
  size = "2GB"
  private_networking = "true"
  ssh_keys = ["${var.droplet_private_key_id}"]
  user_data = "${data.template_file.k8s_cloud_config.rendered}"

  connection {
    user = "${var.droplet_ssh_user}"
    private_key = "${file(var.droplet_private_key_file)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p ${var.k8s_home} ${var.k8s_bin_home} ${var.k8s_unit_files_home} ${var.k8s_auth_home}",
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

  provisioner "file" {
    content = "${data.template_file.unit_file_apiserver.rendered}"
    destination = "${var.k8s_unit_files_home}/kube-apiserver.service"
  }

  provisioner "file" {
    content = "${data.template_file.unit_file_controller.rendered}"
    destination = "${var.k8s_unit_files_home}/kube-controller-manager.service"
  }

  provisioner "file" {
    content = "${data.template_file.unit_file_scheduler.rendered}"
    destination = "${var.k8s_unit_files_home}/kube-scheduler.service"
  }

  provisioner "file" {
    content = "${data.template_file.auth_policy_file.rendered}"
    destination = "${var.k8s_auth_policy_file}"
  }

  provisioner "file" {
    content = "${data.template_file.basic_auth_file.rendered}"
    destination = "${var.k8s_basic_auth_file}"
  }

  provisioner "file" {
    content = "${data.template_file.token_auth_file.rendered}"
    destination = "${var.k8s_token_auth_file}"
  }
}

resource "null_resource" "k8s_master_tls" {
  triggers {
    droplet_id = "${digitalocean_droplet.k8s_master.id}"
    cert = "${tls_locally_signed_cert.k8s_cert.cert_pem}"
  }

  connection {
    user = "${var.droplet_ssh_user}"
    private_key = "${file(var.droplet_private_key_file)}"
    host = "${digitalocean_droplet.k8s_master.ipv4_address}"
  }

  provisioner "remote-exec" {
    inline = <<EOF
sudo mkdir -p ${var.k8s_tls_home}
sudo chown core:core ${var.k8s_tls_home}

sudo cat <<CERT > ${var.k8s_cert_file}
${tls_locally_signed_cert.k8s_cert.cert_pem}
CERT

sudo cat <<KEY > ${var.k8s_key_file}
${tls_private_key.k8s_key.private_key_pem}
KEY

sudo cat <<CERT > ${var.k8s_ca_file}
${tls_self_signed_cert.ca_cert.cert_pem}
CERT

sudo cat <<KEY > ${var.k8s_ca_key_file}
${tls_private_key.ca_key.private_key_pem}
KEY

sudo cat <<CERT > ${var.k8s_client_ca_file}
${tls_self_signed_cert.client_ca_cert.cert_pem}
CERT

sudo cat <<CERT > ${var.k8s_client_cert_file}
${tls_locally_signed_cert.client_cert.cert_pem}
CERT

sudo cat <<KEY > ${var.k8s_client_key_file}
${tls_private_key.client_key.private_key_pem}
KEY
EOF
  }
}

resource "null_resource" "k8s_master_dns" {
  depends_on = ["null_resource.k8s_master_tls"]

  triggers {
    droplet_id = "${digitalocean_droplet.k8s_master.id}"
  }

  connection {
    user = "${var.droplet_ssh_user}"
    private_key = "${file(var.droplet_private_key_file)}"
    host = "${digitalocean_droplet.k8s_master.ipv4_address}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo systemctl restart systemd-resolved",
      "etcdctl --endpoints ${join(",", formatlist("https://%s:%s", digitalocean_droplet.etcd.*.name, var.etcd_client_port))} --ca-file ${var.k8s_ca_file} --key-file ${var.k8s_key_file} --cert-file ${var.k8s_cert_file}  set ${var.skydns_domain_key_path}/${digitalocean_droplet.k8s_master.name} '{\"host\":\"${digitalocean_droplet.k8s_master.ipv4_address_private}\"}'",
      "sudo systemctl enable ${var.k8s_unit_files_home}/*",
      "sudo systemctl start kube-apiserver kube-controller-manager kube-scheduler"
    ]
  }
}


data "template_file" "k8s_cloud_config" {
  template = "${file("${path.module}/k8s/cloud-config")}"

  vars {
    bin_home = "${var.k8s_bin_home}"
    ca_file = "${var.k8s_ca_file}"
    cert_file = "${var.k8s_cert_file}"
    cluster_cidr = "${var.k8s_cluster_cidr}"
    dns_server = "${digitalocean_droplet.skydns.ipv4_address_private}"
    domain = "${var.droplet_domain}"
    etcd_endpoints  = "${join(",", formatlist("https://%s:%s", digitalocean_droplet.etcd.*.name, var.etcd_client_port))}"
    fleet_agent_ttl = "${var.fleet_agent_ttl}"
    fleet_etcd_request_timeout = "${var.fleet_etcd_request_timeout}"
    key_file = "${var.k8s_key_file}"
    resolv_file = "${var.droplet_resolv_file}"
    tls_home = "${var.k8s_tls_home}"
  }
}

data "template_file" "unit_file_apiserver" {
  template = "${file("${path.module}/k8s/master/unit-files/kube-apiserver.service")}"

  vars {
    authorization_policy_file = "${var.k8s_auth_policy_file}"
    basic_auth_file = "${var.k8s_basic_auth_file}"
    ca_file = "${var.k8s_ca_file}"
    cert_file = "${var.k8s_cert_file}"
    client_ca_file = "${var.k8s_client_ca_file}"
    client_cert_file = "${var.k8s_client_cert_file}"
    client_key_file = "${var.k8s_client_key_file}"
    etcd_endpoints = "${join(",", formatlist("https://%s:%s", digitalocean_droplet.etcd.*.name, var.etcd_client_port))}"
    insecure_port = "${var.k8s_apiserver_insecure_port}"
    key_file = "${var.k8s_key_file}"
    secure_port = "${var.k8s_apiserver_secure_port}"
    service_cluster_ip_range = "${var.k8s_service_cluster_ip_range}"
    token_auth_file = "${var.k8s_token_auth_file}"
  }
}

data "template_file" "unit_file_controller" {
  template = "${file("${path.module}/k8s/master/unit-files/kube-controller-manager.service")}"

  vars {
    ca_file = "${var.k8s_ca_file}"
    ca_key_file= "${var.k8s_ca_key_file}"
    cluster_name = "${var.k8s_cluster_name}"
    cluster_cidr = "${var.k8s_cluster_cidr}"
    insecure_port = "${var.k8s_apiserver_insecure_port}"
    key_file = "${var.k8s_key_file}"
    service_cluster_ip_range = "${var.k8s_service_cluster_ip_range}"
  }
}

data "template_file" "unit_file_scheduler" {
  template = "${file("${path.module}/k8s/master/unit-files/kube-scheduler.service")}"

  vars {
    insecure_port = "${var.k8s_apiserver_insecure_port}"
  }
}

data "template_file" "kubeconfig" {
  template = "${file("${path.module}/k8s/workers/kubelet-kubeconfig")}"

  vars {
    apiserver_endpoint = "https://${digitalocean_droplet.k8s_master.name}:${var.k8s_apiserver_secure_port}"
    ca_file = "${var.k8s_ca_file}"
    cluster_name = "${var.k8s_cluster_name}"
    token_kubelet = "${var.k8s_apiserver_token_kubelet}"
  }
}

data "template_file" "auth_policy_file" {
  template = "${file("${path.module}/k8s/master/auth/authorization-policy.json")}"
}

data "template_file" "basic_auth_file" {
  template = "${file("${path.module}/k8s/master/auth/basic")}"

  vars {
    password = "${var.k8s_apiserver_basic_auth_admin}"
  }
}

data "template_file" "token_auth_file" {
  template = "${file("${path.module}/k8s/master/auth/token.csv")}"

  vars {
    token_admin = "${var.k8s_apiserver_token_admin}"
    token_kubelet = "${var.k8s_apiserver_token_kubelet}"
  }
}

resource "digitalocean_droplet" "k8s_worker" {
  depends_on = ["digitalocean_droplet.k8s_master"]

  count = "${var.k8s_workers_count}"
  name = "${format("k8s-worker-%02d", count.index)}"
  image = "${var.coreos_image}"
  region = "${var.droplet_region}"
  size = "2GB"
  private_networking = "true"
  ssh_keys = ["${var.droplet_private_key_id}"]
  user_data = "${data.template_file.k8s_cloud_config.rendered}"

  connection {
    user = "${var.droplet_ssh_user}"
    private_key = "${file(var.droplet_private_key_file)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p ${var.k8s_bin_home} ${var.k8s_lib_home} ${var.k8s_unit_files_home}",
      "sudo chown core:core ${var.k8s_bin_home} ${var.k8s_lib_home} ${var.k8s_unit_files_home}",
      "wget -P ${var.k8s_bin_home} https://storage.googleapis.com/kubernetes-release/release/${var.k8s_version}/bin/linux/amd64/kube-proxy",
      "wget -P ${var.k8s_bin_home} https://storage.googleapis.com/kubernetes-release/release/${var.k8s_version}/bin/linux/amd64/kubelet",
      "wget -P ${var.k8s_bin_home} https://storage.googleapis.com/kubernetes-release/release/${var.k8s_version}/bin/linux/amd64/kubefed",
      "chmod +x ${var.k8s_bin_home}/*",
    ]
  }

  provisioner "file" {
    content = "${data.template_file.kubeconfig.rendered}"
    destination = "${var.k8s_kubeconfig_file}"
  }

  provisioner "file" {
    content = "${data.template_file.unit_file_kubeproxy.rendered}"
    destination = "${var.k8s_unit_files_home}/kube-proxy.service"
  }

  provisioner "file" {
    content = "${data.template_file.unit_file_kubelet.rendered}"
    destination = "${var.k8s_unit_files_home}/kubelet.service"
  }
}

resource "null_resource" "k8s_worker_tls" {
  count = "${var.k8s_workers_count}"
  triggers {
    droplet_id = "${join("," , digitalocean_droplet.k8s_worker.*.id)}"
    cert = "${tls_locally_signed_cert.k8s_cert.cert_pem}"
  }

  connection {
    user = "${var.droplet_ssh_user}"
    private_key = "${file(var.droplet_private_key_file)}"
    host = "${element(digitalocean_droplet.k8s_worker.*.ipv4_address, count.index)}"
  }

  provisioner "remote-exec" {
    inline = <<EOF
sudo mkdir -p ${var.k8s_tls_home}
sudo chown core:core ${var.k8s_tls_home}

sudo cat <<CERT > ${var.k8s_cert_file}
${tls_locally_signed_cert.k8s_cert.cert_pem}
CERT

sudo cat <<KEY > ${var.k8s_key_file}
${tls_private_key.k8s_key.private_key_pem}
KEY

sudo cat <<CERT > ${var.k8s_ca_file}
${tls_self_signed_cert.ca_cert.cert_pem}
CERT
EOF
  }
}

resource "null_resource" "k8s_worker_dns" {
  depends_on = ["null_resource.k8s_worker_tls"]

  count = "${var.k8s_workers_count}"
  triggers {
    droplet_id = "${join("," , digitalocean_droplet.k8s_worker.*.id)}"
  }

  connection {
    user = "${var.droplet_ssh_user}"
    private_key = "${file(var.droplet_private_key_file)}"
    host = "${element(digitalocean_droplet.k8s_worker.*.ipv4_address, count.index)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo systemctl restart systemd-resolved",
      "etcdctl --endpoints ${join(",", formatlist("https://%s:%s", digitalocean_droplet.etcd.*.name, var.etcd_client_port))} --ca-file ${var.k8s_ca_file}  --key-file ${var.k8s_key_file} --cert-file ${var.k8s_cert_file} set ${var.skydns_domain_key_path}/${element(digitalocean_droplet.k8s_worker.*.name, count.index)} '{\"host\":\"${element(digitalocean_droplet.k8s_worker.*.ipv4_address_private, count.index)}\"}'",
      "sudo systemctl enable ${var.k8s_unit_files_home}/*",
      "sudo systemctl start kube-proxy kubelet"
    ]
  }
}

data "template_file" "unit_file_kubelet" {
  template = "${file("${path.module}/k8s/workers/unit-files/kubelet.service")}"

  vars {
    cert_file = "${var.k8s_cert_file}"
    cluster_dns_ip = "${var.k8s_cluster_dns_ip}"
    cluster_domain = "${var.k8s_cluster_domain}"
    key_file = "${var.k8s_key_file}"
    kubeconfig_path = "${var.k8s_kubeconfig_file}"
    lib_home = "${var.k8s_lib_home}"
  }
}

data "template_file" "unit_file_kubeproxy" {
  template = "${file("${path.module}/k8s/workers/unit-files/kube-proxy.service")}"

  vars {
    apiserver_endpoint = "https://${digitalocean_droplet.k8s_master.name}:${var.k8s_apiserver_secure_port}"
    kubeconfig_path = "${var.k8s_kubeconfig_file}"
  }
}

resource "null_resource" "kubectl_config_master" {
  triggers {
    master_id = "${digitalocean_droplet.k8s_master.id}"
  }

  connection {
    user = "${var.droplet_ssh_user}"
    private_key = "${file(var.droplet_private_key_file)}"
    host = "${digitalocean_droplet.k8s_master.ipv4_address}"
  }

  provisioner "remote-exec" {
    inline = [
      "${var.k8s_bin_home}/kubectl config set-cluster ${var.k8s_cluster_name} --server=https://${digitalocean_droplet.k8s_master.name}:${var.k8s_apiserver_secure_port} --certificate-authority=${var.k8s_ca_file}",
      "${var.k8s_bin_home}/kubectl config set-credentials admin --client-certificate=${var.k8s_client_cert_file} --client-key=${var.k8s_client_key_file}",
      "${var.k8s_bin_home}/kubectl config set-context admin --cluster=${var.k8s_cluster_name} --user=admin",
      "${var.k8s_bin_home}/kubectl config use-context admin"
    ]
  }
}

resource "tls_private_key" "kube_apiserver" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "tls_cert_request" "kube_apiserver" {
  key_algorithm = "${tls_private_key.kube_apiserver.algorithm}"
  private_key_pem = "${tls_private_key.kube_apiserver.private_key_pem}"

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
  ca_key_algorithm = "${tls_private_key.ca_key.algorithm}"
  ca_private_key_pem = "${tls_private_key.ca_key.private_key_pem}"
  ca_cert_pem = "${tls_self_signed_cert.ca_cert.cert_pem}"
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
  ca_key_algorithm = "${tls_private_key.ca_key.algorithm}"
  ca_private_key_pem = "${tls_private_key.ca_key.private_key_pem}"
  ca_cert_pem = "${tls_self_signed_cert.ca_cert.cert_pem}"
  validity_period_hours = "${var.tls_cert_validity_period_hours}"
  early_renewal_hours = "${var.tls_cert_early_renewal_hours}"

  allowed_uses = [
    "server_auth",
    "client_auth"
  ]
}

resource "tls_private_key" "k8s_workers" {
  count = "${var.k8s_workers_count}"

  algorithm = "RSA"
  rsa_bits = 4096
}

resource "tls_cert_request" "k8s_workers" {
  count = "${var.k8s_workers_count}"

  key_algorithm = "${element(tls_private_key.k8s_workers.*.algorithm, count.index)}"
  private_key_pem = "${element(tls_private_key.k8s_workers.*.private_key_pem, count.index)}"

  subject {
    common_name = "${var.tls_workers_cert_subject_common_name}:${count.index}"
    organization = "${var.tls_workers_cert_subject_organization}"
    organizational_unit = "${var.tls_cert_subject_organizational_unit}"
    street_address = ["${var.tls_cert_subject_street_address}"]
    locality = "${var.tls_cert_subject_locality}"
    province = "${var.tls_cert_subject_province}"
    country = "${var.tls_cert_subject_country}"
    postal_code = "${var.tls_cert_subject_postal_code}"
  }

  ip_addresses = [
    "${element(digitalocean_droplet.k8s_workers.*.ipv4_address_private, count.index)}",
  ]
}

resource "tls_locally_signed_cert" "k8s_workers" {
  count = "${var.k8s_workers_count}"

  cert_request_pem = "${element(tls_cert_request.k8s_workers.*.cert_request_pem, count.index)}"
  ca_key_algorithm = "${tls_private_key.ca_key.algorithm}"
  ca_private_key_pem = "${tls_private_key.ca_key.private_key_pem}"
  ca_cert_pem = "${tls_self_signed_cert.ca_cert.cert_pem}"
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
  ca_key_algorithm = "${tls_private_key.ca_key.algorithm}"
  ca_private_key_pem = "${tls_private_key.ca_key.private_key_pem}"
  ca_cert_pem = "${tls_self_signed_cert.ca_cert.cert_pem}"
  validity_period_hours = "${var.tls_cert_validity_period_hours}"
  early_renewal_hours = "${var.tls_cert_early_renewal_hours}"

  allowed_uses = [
    "server_auth",
    "client_auth"
  ]
}
