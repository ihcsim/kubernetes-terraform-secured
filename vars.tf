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

variable "droplet_region" {
  default = "sfo2"
}

variable "droplet_domain" {
  default = "default.cluster"
  description = "All droplets will be assigned FQDN in the form of <name>.<region>.<droplet_domain>."
}

variable "droplet_tls_certs_home" {
  default = "/etc/ssl/certs"
}

variable "droplet_resolv_home" {
  default = "/etc/systemd/resolved.conf.d/"
}

variable "droplet_resolv_file" {
  default = "/etc/systemd/resolved.conf.d/droplet.conf"
}

variable "droplet_maintenance_window_start" {
  default = "Sun 1:00"
}

variable "droplet_maintenance_window_length" {
  default = "2h"
}

variable "droplet_update_channel" {
  default = "stable"
}

variable "coreos_image" {
  default = "27616485"
  description = "Image ID of CoreOS 1465.6.0."
}

variable "etcd_discovery_url" {
  description = "Discovery URL obtained from https://discovery.etcd.io/new?size=N where N is the size of the etcd cluster. This must be generated for every new etcd cluster."
}

variable "etcd_version" {
  default = "3.2.0"
}

variable "etcd_count" {
  default = 3
}

variable "etcd_data_dir" {
  default = "/var/lib/etcd"
}

variable "etcd_client_port" {
  default = 2379
}

variable "etcd_peer_port" {
  default = 2380
}

variable "etcd_heartbeat_interval" {
  default = 5000
}

variable "etcd_election_timeout" {
  default = 5000
}

variable "k8s_version" {
  default = "v1.7.0"
}

variable "k8s_cluster_name" {
  default = "do-k8s"
}

variable "k8s_cluster_dns_ip" {
	default = "10.32.0.10"
}

variable "k8s_cluster_domain" {
  default = "kubernetes.internal"
}

variable "k8s_cluster_cidr" {
  default = "10.200.0.0/16"
}

variable "k8s_service_cluster_ip_range" {
  default = "10.32.0.0/24"
}

variable "k8s_service_node_port_range" {
  default = "30000-32767"
}

variable "k8s_apiserver_count" {
  default = 1
}

variable "k8s_apiserver_insecure_port" {
  default = 8080
}

variable "k8s_apiserver_secure_port" {
  default = 6443
}

variable "k8s_apiserver_encryption_key" {
  description = "Encryption key used in the API server's encryption config"
}

variable "k8s_apiserver_encryption_config_file" {
  default = "/opt/k8s/encryption-config.yaml"
}

variable "tls_cacert_file" {
  default = "cacert.pem"
}

variable "tls_cakey_file" {
  default = "cakey.pem"
}

variable "tls_key_file" {
  default = "key.pem"
}

variable "tls_cert_file" {
  default = "cert.pem"
}

variable "tls_cacert_subject_common_name" {
  description = "The self-generated CA cert subject common name used to sign all cluster certs. The cluster certs are used to secure and validate inter-cluster requests. The subject common name of this CA cert must be different from the subject common name for the Kubernetes' certificates. Otherwise, Kubernetes will fail, complaining that it's been assigned a self-signed certificate."
}

variable "tls_cacert_subject_organization" {
  description = "The self-generated CA cert subject organization name."
}

variable "tls_etcd_cert_subject_common_name" {
  description = "The etcd TLS cert subject organization name."
  default = "system:etcd"
}

variable "tls_etcd_cert_subject_organization" {
  description = "The etcd TLS cert subject organization name."
  default = "system:etcd"
}

variable "tls_kube_apiserver_cert_subject_common_name" {
  description = "The kubernetes API Server TLS cert subject organization name."
  default = "kubernetes"
}

variable "tls_kube_apiserver_cert_subject_organization" {
  description = "The kubernetes API Server TLS cert subject organization name."
  default = "kubernetes"
}

variable "tls_kube_proxy_cert_subject_common_name" {
  description = "The kube-proxy TLS cert subject organization name."
  default = "system:kube-proxy"
}

variable "tls_kube_proxy_cert_subject_organization" {
  description = "The kube-proxy TLS cert subject organization name."
  default = "system:node-proxier"
}

variable "tls_workers_cert_subject_common_name" {
  description = "The workers' TLS cert subject organization name."
  default = "system:node"
}

variable "tls_workers_cert_subject_organization" {
  description = "The workers' TLS cert subject organization name."
  default = "system:nodes"
}

variable "tls_client_cert_subject_common_name" {
  description = "The client's TLS cert subject common name. Kubernetes uses this as the user name for the request. Refer http://kubernetes.io/docs/admin/authentication/#x509-client-certs"
  default = "admin"
}

variable "tls_client_cert_subject_organization" {
  description = "The client's TLS cert subject organization name. As of Kubernetes 1.4, Kubernetes uses this as the user's group. Refer http://kubernetes.io/docs/admin/authentication/#x509-client-certs"
  default = "system:masters"
}

variable "tls_cert_subject_organizational_unit" {
  description = "The Kubernetes and etcd clusters' TLS cert subject organizational unit."
}

variable "tls_cert_subject_street_address" {
  description = "The Kubernetes and etcd clusters' TLS cert subject street address."
}

variable "tls_cert_subject_locality" {
  description = "The Kubernetes and etcd clusters' TLS cert subject locality."
}

variable "tls_cert_subject_province" {
  description = "The Kubernetes and etcd clusters' TLS cert subject postal code."
}

variable "tls_cert_subject_postal_code" {
  description = "The Kubernetes and etcd clusters' TLS cert subject postal code."
}

variable "tls_cert_subject_country" {
  description = "The Kubernetes and etcd clusters' TLS cert subject 2-letter country code."
}

variable "tls_cert_validity_period_hours" {
  description = "The validity period in hours of the Kubernetes and etcd clusters' TLS cert."
}

variable "tls_cert_early_renewal_hours" {
  description = "The early renewal period in hours of the Kubernetes and etcd clusters' TLS cert. Set this variable to a time period that is earlier than the cert validity to force Terraform to generate a new cert before the existing one expires. "
}

variable "k8s_home" {
  default = "/opt/k8s"
}

variable "k8s_bin_home" {
  default = "/opt/k8s/bin"
}

variable "k8s_lib_home" {
  default = "/opt/k8s/lib"
}

variable "k8s_lib_kubelet_home" {
  default = "/opt/k8s/lib/kubelet"
}

variable "k8s_lib_kube_proxy_home" {
  default = "/opt/k8s/lib/kube-proxy"
}

variable "k8s_workers_count" {
  default = 3
}
