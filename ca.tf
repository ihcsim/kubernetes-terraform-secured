resource "tls_private_key" "cakey" {
  algorithm = "RSA"
  rsa_bits = 4096
}

resource "tls_self_signed_cert" "cacert" {
  key_algorithm = "${tls_private_key.cakey.algorithm}"
  private_key_pem = "${tls_private_key.cakey.private_key_pem}"

  subject {
    common_name = "${var.tls_cacert_subject_common_name}"
    organization = "${var.tls_cacert_subject_organization}"
    organizational_unit = "${var.tls_cert_subject_organizational_unit}"
    street_address = ["${var.tls_cert_subject_street_address}"]
    locality = "${var.tls_cert_subject_locality}"
    province = "${var.tls_cert_subject_province}"
    country = "${var.tls_cert_subject_country}"
    postal_code = "${var.tls_cert_subject_postal_code}"
  }

  validity_period_hours = "${var.tls_cert_validity_period_hours}"
  early_renewal_hours = "${var.tls_cert_early_renewal_hours}"

  allowed_uses = [
    "key_encipherment",
    "server_auth",
    "client_auth",
    "cert_signing"
  ]

  is_ca_certificate = true
}
