resource "null_resource" "kube_system_apps" {
  depends_on = ["null_resource.k8s_master_tls"]

  triggers {
    master_id = "${digitalocean_droplet.k8s_master.id}"
  }

  connection {
    user = "${var.droplet_ssh_user}"
    private_key = "${file(var.droplet_private_key_file)}"
    host = "${digitalocean_droplet.k8s_master.ipv4_address}"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p ${var.k8s_apps_home}",
      "sudo chown core:core ${var.k8s_apps_home}"
    ]
  }

  provisioner "file" {
    content = "${data.template_file.deployment_kubedns.rendered}"
    destination = "${var.k8s_apps_home}/kubedns.yml"
  }

  provisioner "file" {
    content = "${data.template_file.deployment_dashboard.rendered}"
    destination = "${var.k8s_apps_home}/dashboard.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "${var.k8s_bin_home}/kubectl create -f ${var.k8s_apps_home}/kubedns.yml",
      "${var.k8s_bin_home}/kubectl create -f ${var.k8s_apps_home}/dashboard.yml"
    ]
  }
}

data "template_file" "deployment_kubedns" {
  template = "${file("${path.module}/apps/kubedns/deployment.yml")}"

  vars {
    cluster_dns_ip = "${var.k8s_cluster_dns_ip}"
    cluster_domain = "${var.k8s_cluster_domain}"
    lib_home = "${var.k8s_lib_home}"
    kubeconfig_file = "${var.k8s_kubeconfig_file}"
    tls_home = "${var.k8s_tls_home}"
  }
}

data "template_file" "deployment_dashboard" {
  template = "${file("${path.module}/apps/dashboard/deployment.yml")}"

  vars {
    lib_home = "${var.k8s_lib_home}"
    kubeconfig_file = "${var.k8s_kubeconfig_file}"
    tls_home = "${var.k8s_tls_home}"
  }
}

