output "Kubernetes API" {
  value = "${format("https://%s:%s", digitalocean_droplet.k8s_masters.0.ipv4_address, var.k8s_apiserver_secure_port)}"
}

output "Kubernetes Dashboard" {
  value = "${format("https://%s:%s/ui", digitalocean_droplet.k8s_masters.0.ipv4_address, var.k8s_apiserver_secure_port)}"
}

output "Kubernetes Swagger Docs" {
  value = "${format("https://%s:%s/swagger-ui", digitalocean_droplet.k8s_masters.0.ipv4_address, var.k8s_apiserver_secure_port)}"
}
