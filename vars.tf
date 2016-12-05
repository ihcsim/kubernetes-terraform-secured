variable "do_api_token" {
  description = "DigitalOcean API access token. This can be generated from the DigitalOcean web console."
}

variable "droplet_ssh_user" {
  description = "SSH user used by Terraform's 'connection' provisioner to access the droplets."
}

variable "droplet_private_key_file" {
  description = "Path to the private key used by Terraform's 'connecton' provisioner to access the droplets."
}

variable "droplet_private_key_id" {
  description = "ID of the SSH key used by Terraform to create the droplets. This can be obtained from the DigitalOcean web console or CLI."
}

variable "etcd_discovery_url" {
  description = "Discovery URL obtained from https://discovery.etcd.io/new?size=N where N is the size of the etcd cluster. This must be generated for every new etcd cluster."
}

variable "k8s_apiserver_token_admin" {
  description = "The 'admin' user's bearer token used to authenticate against the API Server. Refer http://kubernetes.io/docs/admin/authentication/#static-token-file for more details."
}

variable "k8s_apiserver_token_kubelet" {
  description = "The 'kubelet' user's bearer token used to authenticate against the API Server. Refer http://kubernetes.io/docs/admin/authentication/#static-token-file for more details."
}

variable "k8s_apiserver_basic_auth_admin" {
  description = "Basic authentication password for the 'admin' user to access the Kubernetes dashboard. Refer http://kubernetes.io/docs/admin/authentication/#static-password-file for more details."
}

variable "tls_ca_cert_subject_common_name" {
  description = "The self-generated CA cert subject common name used to sign all cluster certs. The cluster certs are used to secure and validate inter-cluster requests. The subject common name of this CA cert must be different from the subject common name for the Kubernetes' certificates. Otherwise, Kubernetes will fail, complaining that it's been assigned a self-signed certificate."
}

variable "tls_cluster_cert_subject_common_name" {
  description = "The Kubernetes and etcd clusters' TLS cert subject common name."
}

variable "tls_cluster_cert_subject_organization" {
  description = "The Kubernetes and etcd clusters' TLS cert subject organization name."
}

variable "tls_cluster_cert_subject_organizational_unit" {
  description = "The Kubernetes and etcd clusters' TLS cert subject organizational unit."
}

variable "tls_cluster_cert_subject_street_address" {
  description = "The Kubernetes and etcd clusters' TLS cert subject street address."
}

variable "tls_cluster_cert_subject_locality" {
  description = "The Kubernetes and etcd clusters' TLS cert subject locality."
}

variable "tls_cluster_cert_subject_province" {
  description = "The Kubernetes and etcd clusters' TLS cert subject postal code."
}

variable "tls_cluster_cert_subject_postal_code" {
  description = "The Kubernetes and etcd clusters' TLS cert subject postal code."
}

variable "tls_cluster_cert_subject_country" {
  description = "The Kubernetes and etcd clusters' TLS cert subject 2-letter country code."
}

variable "tls_cluster_cert_subject_serial_number" {
  description = "The Kubernetes and etcd clusters' TLS cert subject serial number."
}

variable "tls_cluster_cert_validity_period_hours" {
  descrption = "The validity period in hours of the Kubernetes and etcd clusters' TLS cert."
}

variable "tls_cluster_cert_early_renewal_hours" {
  description = "The early renewal period in hours of the Kubernetes and etcd clusters' TLS cert. Set this variable to a time period that is earlier than the cert validity to force Terraform to generate a new cert before the existing one expires. "
}

variable "tls_client_cert_subject_common_name" {
  description = "The external client's TLS cert subject common name. Kubernetes uses this as the user name for the request. Refer http://kubernetes.io/docs/admin/authentication/#x509-client-certs"
}

variable "tls_client_cert_subject_organization" {
  description = "The external client's TLS cert subject organization name. As of Kubernetes 1.4, Kubernetes uses this as the user's group. Refer http://kubernetes.io/docs/admin/authentication/#x509-client-certs"
}

variable "tls_client_cert_subject_organizational_unit" {
  description = "The external client's TLS cert subject organizational unit."
}

variable "tls_client_cert_subject_street_address" {
  description = "The external client's TLS cert subject street address."
}

variable "tls_client_cert_subject_locality" {
  description = "The external client's TLS cert subject locality."
}

variable "tls_client_cert_subject_province" {
  description = "The external client's TLS cert subject postal code."
}

variable "tls_client_cert_subject_postal_code" {
  description = "The external client's TLS cert subject postal code."
}

variable "tls_client_cert_subject_country" {
  description = "The external client's TLS cert subject 2-letter country code."
}

variable "tls_client_cert_subject_serial_number" {
  description = "The external client's TLS cert subject serial number."
}

variable "tls_client_cert_validity_period_hours" {
  descrption = "The validity period in hours of the external client's TLS cert."
}

variable "tls_client_cert_early_renewal_hours" {
  description = "The early renewal period in hours of the external client's TLS cert. Set this variable to a time period that is earlier than the cert validity to force Terraform to generate a new cert before the existing one expires. "
}

variable "droplet_region" {
  default = "sfo2"
}

variable "coreos_image" {
  default = "coreos-stable"
}

variable "etcd_count" {
  default = 3
}

variable "etcd_client_port" {
  default = 2379
}

variable "etcd_peer_port" {
  default = 2380
}

variable "etcd_heartbeat_interval" {
  default = 1000
}

variable "etcd_election_timeout" {
  default = 5000
}

variable "etcd_tls_home" {
  default = "/etc/etcd/tls/"
}

variable "etcd_key_file" {
  default = "/etc/etcd/tls/key.pem"
}

variable "etcd_cert_file" {
  default = "/etc/etcd/tls/cert.pem"
}

variable "etcd_trusted_ca_file" {
  default = "/etc/etcd/tls/ca.pem"
}

variable "fleet_agent_ttl" {
  default = "60s"
}

variable "fleet_etcd_request_timeout" {
  default = "5.0"
}

variable "local_tls_home" {
  default = ".tls"
}

variable "local_ca_file" {
  default = ".tls/ca.pem"
}

variable "local_etcd_cert_file" {
  default = ".tls/etcd-cert.pem"
}

variable "local_etcd_key_file" {
  default = ".tls/etcd-key.pem"
}

variable "local_kubectl_cert_file" {
  default = ".tls/kubectl-cert.pem"
}

variable "local_kubectl_key_file" {
  default = ".tls/kubectl-key.pem"
}

variable "k8s_version" {
  default = "v1.4.0"
}

variable "k8s_cluster_name" {
  default = "do-k8s"
}

variable "k8s_tls_home" {
  default = "/opt/k8s/tls"
}

variable "k8s_key_file" {
  default = "/opt/k8s/tls/key.pem"
}

variable "k8s_cert_file" {
  default = "/opt/k8s/tls/cert.pem"
}

variable "k8s_ca_file" {
  default = "/opt/k8s/tls/ca.pem"
}

variable "k8s_ca_key_file" {
  default = "/opt/k8s/tls/ca-key.pem"
}

variable "k8s_client_ca_file" {
  default = "/opt/k8s/tls/client-ca.pem"
}

variable "k8s_client_cert_file" {
  default = "/opt/k8s/tls/client-cert.pem"
}

variable "k8s_client_key_file" {
  default = "/opt/k8s/tls/client-key.pem"
}

variable "k8s_cluster_dns_ip" {
	default = "10.32.0.10"
}

variable "k8s_cluster_domain" {
  default = "k8s.cloud"
}

variable "k8s_cluster_cidr" {
  default = "10.200.0.0/16"
}

variable "k8s_apiserver_insecure_port" {
  default = 7000
}

variable "k8s_apiserver_secure_port" {
  default = 6443
}

variable "k8s_service_cluster_ip_range" {
  default = "10.32.0.0/24"
}

variable "k8s_home" {
  default = "/opt/k8s"
}

variable "k8s_apps_home" {
  default = "/opt/k8s/apps"
}

variable "k8s_bin_home" {
  default = "/opt/k8s/bin"
}

variable "k8s_lib_home" {
  default = "/opt/k8s/lib"
}

variable "k8s_kubeconfig_file" {
  default = "/opt/k8s/lib/kubeconfig"
}

variable "k8s_unit_files_home" {
  default = "/opt/k8s/unit-files"
}

variable "k8s_auth_home" {
  default = "/opt/k8s/auth"
}

variable "k8s_auth_policy_file" {
  default = "/opt/k8s/auth/authorization-policy.json"
}

variable "k8s_basic_auth_file" {
  default = "/opt/k8s/auth/basic"
}

variable "k8s_token_auth_file" {
  default = "/opt/k8s/auth/token.csv"
}

variable "k8s_worker_count" {
  default = 2
}

variable "k8s_worker_hostname" {
  default = "k8s-worker"
}

variable "k8s_dns_home" {
	default = "/opt/k8s/dns"
}

variable "k8s_dns_service_file" {
  default = "/opt/k8s/dns/service.yml"
}

variable "k8s_dns_deployment_file" {
  default = "/opt/k8s/dns/deployment.yml"
}
