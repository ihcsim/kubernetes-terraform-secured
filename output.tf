output "kubeconfig" {
  value = "\n${data.template_file.kubeconfig.rendered}"
}
