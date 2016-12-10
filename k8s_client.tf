/*
 * This script generate the TLS artifacts for clients such as kubectl to access the Kubernetes cluster.
 */
resource "tls_private_key" "client_key" {
  algorithm = "RSA"
  rsa_bits = 2048
}

resource "tls_self_signed_cert" "client_ca_cert" {
  key_algorithm = "${tls_private_key.client_key.algorithm}"
  private_key_pem = "${tls_private_key.client_key.private_key_pem}"
  subject {
    common_name = "${var.tls_client_cert_subject_common_name}"
    organization = "${var.tls_client_cert_subject_organization}"
    organizational_unit = "${var.tls_client_cert_subject_organizational_unit}"
    street_address = ["${var.tls_client_cert_subject_street_address}"]
    locality = "${var.tls_client_cert_subject_locality}"
    province = "${var.tls_client_cert_subject_province}"
    country = "${var.tls_client_cert_subject_country}"
    postal_code = "${var.tls_client_cert_subject_postal_code}"
    serial_number = "${var.tls_client_cert_subject_serial_number}"
  }
  validity_period_hours = "${var.tls_client_cert_validity_period_hours}"
  allowed_uses = [
    "key_encipherment",
    "client_auth",
    "cert_signing"
  ]
  early_renewal_hours = "${var.tls_client_cert_early_renewal_hours}"
  is_ca_certificate = true
}

resource "tls_cert_request" "client_csr" {
  key_algorithm = "${tls_private_key.client_key.algorithm}"
  private_key_pem = "${tls_private_key.client_key.private_key_pem}"
  subject {
    common_name = "${var.tls_client_cert_subject_common_name}"
    organization = "${var.tls_client_cert_subject_organization}"
    organizational_unit = "${var.tls_client_cert_subject_organizational_unit}"
    street_address = ["${var.tls_client_cert_subject_street_address}"]
    locality = "${var.tls_client_cert_subject_locality}"
    province = "${var.tls_client_cert_subject_province}"
    country = "${var.tls_client_cert_subject_country}"
    postal_code = "${var.tls_client_cert_subject_postal_code}"
    serial_number = "${var.tls_client_cert_subject_serial_number}"
  }
}

resource "tls_locally_signed_cert" "client_cert" {
  cert_request_pem = "${tls_cert_request.client_csr.cert_request_pem}"
  ca_key_algorithm = "${tls_private_key.client_key.algorithm}"
  ca_private_key_pem = "${tls_private_key.client_key.private_key_pem}"
  ca_cert_pem = "${tls_self_signed_cert.client_ca_cert.cert_pem}"
  validity_period_hours = "${var.tls_client_cert_validity_period_hours}"
  allowed_uses = [
    "key_encipherment",
    "client_auth",
  ]
  early_renewal_hours = "${var.tls_client_cert_early_renewal_hours}"
}
