resource "null_resource" "client_kubeconfig" {
  triggers {
    master = "${digitalocean_droplet.k8s_masters.0.id}"
  }

  depends_on = ["null_resource.k8s_masters_tls"]

  provisioner "local-exec" {
     command = <<EOT
       rm -f ${path.module}/.kubeconfig
       echo "${data.template_file.client_kubeconfig.rendered}" >> ${path.module}/.kubeconfig
       sleep 120
       kubectl --kubeconfig=${path.module}/.kubeconfig cluster-info
       kubectl --kubeconfig=${path.module}/.kubeconfig get componentstatus
     EOT
  }
}


data "template_file" "client_kubeconfig" {
  template = "${file("${path.module}/k8s/client/kubeconfig")}"

  vars {
    apiserver_endpoint = "${format("https://%s:%s", digitalocean_droplet.k8s_masters.0.ipv4_address, var.k8s_apiserver_secure_port)}"

     cacert = "${base64encode(tls_self_signed_cert.cacert.cert_pem)}"
     client_cert = "${base64encode(tls_locally_signed_cert.k8s_admin_client.cert_pem)}"
     client_key = "${base64encode(tls_private_key.k8s_admin_client.private_key_pem)}"

    cluster_name = "${var.k8s_cluster_name}"
    username = "${var.tls_client_cert_subject_common_name}"
  }
}

resource "tls_private_key" "k8s_admin_client" {
  algorithm = "RSA"
  rsa_bits = 2048
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
