/*
 * This script saves all client-side TLS artifacts into a local folder defined by the `var.local_tls_home` variable.
 * Comment out this script if you don't want any of these artifacts to be output to your local machine.
 */
resource "null_resource" "ca_cert" {
  triggers {
    cert = "${tls_self_signed_cert.ca_cert.cert_pem}"
  }

  provisioner "local-exec" {
    command = <<EOF
mkdir -p ${var.local_tls_home}
cat <<CERT > ${var.local_ca_file}
${tls_self_signed_cert.ca_cert.cert_pem}
CERT
    EOF
  }
}

resource "null_resource" "etcd_cert" {
  triggers {
    cert = "${tls_locally_signed_cert.etcd_cert.cert_pem}"
  }

  provisioner "local-exec" {
    command = <<EOF
mkdir -p ${var.local_tls_home}
cat <<CERT > ${var.local_etcd_cert_file}
${tls_locally_signed_cert.etcd_cert.cert_pem}
CERT
    EOF
  }
}

resource "null_resource" "etcd_key" {
  triggers {
    cert = "${tls_private_key.etcd_key.private_key_pem}"
  }

  provisioner "local-exec" {
    command = <<EOF
mkdir -p ${var.local_tls_home}
cat <<KEY > ${var.local_etcd_key_file}
${tls_private_key.etcd_key.private_key_pem}
KEY
    EOF
  }
}

resource "null_resource" "kubectl_cert" {
  triggers {
    cert = "${tls_locally_signed_cert.client_cert.cert_pem}"
  }

  provisioner "local-exec" {
    command = <<EOF
mkdir -p ${var.local_tls_home}
cat <<CERT > ${var.local_kubectl_cert_file}
${tls_locally_signed_cert.client_cert.cert_pem}
CERT
    EOF
  }
}

resource "null_resource" "kubectl_key" {
  triggers {
    cert = "${tls_private_key.client_key.private_key_pem}"
  }

  provisioner "local-exec" {
    command = <<EOF
mkdir -p ${var.local_tls_home}
cat <<KEY > ${var.local_kubectl_key_file}
${tls_private_key.client_key.private_key_pem}
KEY
    EOF
  }
}
