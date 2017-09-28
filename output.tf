output "bearer token" {
  value = "${var.k8s_apiserver_client_token}"
}

output "kubeconfig" {
  value = "\n${data.template_file.kubeconfig.rendered}"
}
