/*
This script deploys a secured Kubernetes cluster with one master node and two workers node. The TLS artifacts are generated locally by the TLS provider and copy to the remote nodes using "null resources" after the nodes are created.
 */

output "Kubernetes Master" {
  value = "${format("https://%s:%s", digitalocean_droplet.k8s_master.ipv4_address, var.k8s_apiserver_secure_port)}"
}

provider "digitalocean" {
  token = "${var.do_api_token}"
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
      "wget -P ${var.k8s_bin_home} https://storage.googleapis.com/kubernetes-release/release/${var.k8s_version}/bin/linux/amd64/kube-apiserver",
      "wget -P ${var.k8s_bin_home} https://storage.googleapis.com/kubernetes-release/release/${var.k8s_version}/bin/linux/amd64/kube-controller-manager",
      "wget -P ${var.k8s_bin_home} https://storage.googleapis.com/kubernetes-release/release/${var.k8s_version}/bin/linux/amd64/kube-scheduler",
      "wget -P ${var.k8s_bin_home} https://storage.googleapis.com/kubernetes-release/release/${var.k8s_version}/bin/linux/amd64/kubectl",
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
    inline = [
      "sudo mkdir -p ${var.k8s_tls_home}",
      "sudo chown core:core ${var.k8s_tls_home}",
      "sudo cat <<EOF > ${var.k8s_cert_file}
${tls_locally_signed_cert.k8s_cert.cert_pem}
EOF",
      "sudo cat <<EOF > ${var.k8s_key_file}
${tls_private_key.k8s_key.private_key_pem}
EOF",
      "sudo cat <<EOF > ${var.k8s_ca_file}
${tls_self_signed_cert.ca_cert.cert_pem}
EOF",
      "sudo cat <<EOF > ${var.k8s_ca_key_file}
${tls_private_key.ca_key.private_key_pem}
EOF",
      "sudo cat <<EOF > ${var.k8s_client_ca_file}
${tls_self_signed_cert.client_ca_cert.cert_pem}
EOF",
      "sudo cat <<EOF > ${var.k8s_client_cert_file}
${tls_locally_signed_cert.client_cert.cert_pem}
EOF",
      "sudo cat <<EOF > ${var.k8s_client_key_file}
${tls_private_key.client_key.private_key_pem}
EOF",
      "sudo systemctl enable ${var.k8s_unit_files_home}/*",
      "sudo systemctl restart kube-apiserver kube-controller-manager kube-scheduler"
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
    etcd_endpoints  = "${join(",", formatlist("https://%s:2379", digitalocean_droplet.etcd.*.ipv4_address_private))}"
    fleet_agent_ttl = "${var.fleet_agent_ttl}"
    fleet_etcd_request_timeout = "${var.fleet_etcd_request_timeout}"
    key_file = "${var.k8s_key_file}"
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
    etcd_endpoints = "${join(",", formatlist("https://%s:2379", digitalocean_droplet.etcd.*.ipv4_address_private))}"
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
    apiserver_endpoint = "${format("https://%s:%s", digitalocean_droplet.k8s_master.ipv4_address_private, var.k8s_apiserver_secure_port)}"
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

  count = "${var.k8s_worker_count}"
  name = "${format("${var.k8s_worker_hostname}-%02d", count.index)}"
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
      "chmod +x ${var.k8s_bin_home}/*"
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
  count = "${var.k8s_worker_count}"
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
    inline = [
      "sudo mkdir -p ${var.k8s_tls_home}",
      "sudo chown core:core ${var.k8s_tls_home}",
      "sudo cat <<EOF > ${var.k8s_cert_file}
${tls_locally_signed_cert.k8s_cert.cert_pem}
EOF",
      "sudo cat <<EOF > ${var.k8s_key_file}
${tls_private_key.k8s_key.private_key_pem}
EOF",
      "sudo cat <<EOF > ${var.k8s_ca_file}
${tls_self_signed_cert.ca_cert.cert_pem}
EOF",
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
    apiserver_endpoint = "${format("https://%s:%s", digitalocean_droplet.k8s_master.ipv4_address_private, var.k8s_apiserver_secure_port)}"
    kubeconfig_path = "${var.k8s_kubeconfig_file}"
  }
}

resource "tls_private_key" "k8s_key" {
  algorithm = "RSA"
  rsa_bits = 2048
}

resource "tls_cert_request" "k8s_csr" {
  key_algorithm = "${tls_private_key.k8s_key.algorithm}"
  private_key_pem = "${tls_private_key.k8s_key.private_key_pem}"
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
    "${digitalocean_droplet.k8s_master.ipv4_address}",
    "${digitalocean_droplet.k8s_master.ipv4_address_private}",
    "${digitalocean_droplet.k8s_worker.*.ipv4_address}",
    "${digitalocean_droplet.k8s_worker.*.ipv4_address_private}",
  ]
}

resource "tls_locally_signed_cert" "k8s_cert" {
  cert_request_pem = "${tls_cert_request.k8s_csr.cert_request_pem}"
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

/*
resource "null_resource" "dns" {
  triggers {
    id = "${digitalocean_droplet.k8s_master.id}"
  }

  connection {
    host = "${digitalocean_droplet.k8s_master.ipv4_address}"
    user = "${var.do_ssh_user}"
    private_key = "${file(var.do_ssh_private_key)}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p ${var.k8s_dns_home}",
      "sudo chown core ${var.k8s_dns_home}"
    ]
  }

  provisioner "file" {
		content = "${data.template_file.k8s_dns_service_file.rendered}"
		destination = "${var.k8s_dns_service_file}"
	}

	provisioner "file" {
		content = "${data.template_file.k8s_dns_deployment_file.rendered}"
		destination = "${var.k8s_dns_deployment_file}"
	}

  provisioner "remote-exec" {
    inline = [
			"./kubectl config set-cluster ${var.k8s_cluster_name} --server=http://${digitalocean_droplet.k8s_master.ipv4_address_private}:${var.k8s_apiserver_insecure_port}",
			"./kubectl config set-credentials ${var.k8s_auth_admin_user} --token ${var.k8s_auth_admin_token}",
			"./kubectl config set-context default-context --cluster=${var.k8s_cluster_name} --user=${var.k8s_auth_admin_user}",
			"./kubectl config use-context default-context",
      "./kubectl create -f ${var.k8s_dns_service_file}",
      "./kubectl create -f ${var.k8s_dns_deployment_file}"
    ]
  }
}

data "template_file" "k8s_dns_service_file" {
	template = "${file("${path.module}/k8s/master/dns/service.yml")}"

	vars {
		cluster_dns_ip = "${var.k8s_cluster_dns_ip}"
	}
}

data "template_file" "k8s_dns_deployment_file" {
	template = "${file("${path.module}/k8s/master/dns/deployment.yml")}"

	vars {
		cluster_domain = "${var.k8s_cluster_domain}"
    kube_master_url = "${format("http://%s:%s", digitalocean_droplet.k8s_master.ipv4_address, var.k8s_apiserver_insecure_port)}"
	}
}*/
