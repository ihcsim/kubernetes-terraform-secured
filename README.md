# kubernetes-terraform-secured

This project uses [Terraform](https://www.terraform.io/) to provision [Kubernetes](https://kubernetes.io/) on [DigitalOcean](https://www.digitalocean.com/), with [Container Linux](https://coreos.com/os/docs/latest).

**Note that the droplets and volumes created as part of this project aren't free.**

## Table of Content

* [Prerequisites](#prerequisites)
* [Getting Started](#getting-started)
* [Cluster Layout](#cluster-layout)
  * [etcd3](#etcd3)
  * [Kubernetes](#kubernetes)
* [Add-ons](#add-ons)
* [Droplet Updates](#droplet-updates)
* [License](#license)
* [References](#references)

## Prerequisites

* [Terraform v0.10.0](https://www.terraform.io/downloads.html)
* [Container Linux Config Transpiler Provider](https://github.com/coreos/terraform-provider-ct)
* [Go 1.8.3](https://golang.org/dl/)
* [doctl 1.7.0](https://github.com/digitalocean/doctl)

## Getting Started
To get started, clone this repository:
```sh
$ git clone git@github.com:ihcsim/kubernetes-terraform-secured.git
```

Initialize the project:
```sh
$ terraform init
```

The above command will fail with errors complaining about the missing [Config Transpiler provider](https://github.com/coreos/terraform-provider-ct). Since at the time of this writing, the Linux Container's Config Transpiler provider isn't included in the official [Terraform Providers repository](https://github.com/terraform-providers), you must manually copy it into your local `kubernetes-terraform-secured/.terraform` folder.

Use the following commands to install the Config Transpiler provider:
```sh
$ go get -u github.com/coreos/terraform-provider-ct
$ cp $GOPATH/bin/terraform-provider-ct kuberntes-terraform-secured/.terraform/plugins/<os_arch>/
```

Re-initialize the project:
```sh
$ terraform init
```

Create a copy of the `terraform.tfvars` file from the provided `terraform.tfvars.sample` file. Provide all the required values. The description of all these variables can be found in the `vars.tf` file.

Provision the Kubernetes cluster:
```sh
$ terraform apply
var.etcd_discovery_url
  Discovery URL obtained from https://discovery.etcd.io/new?size=N where N is the size of the etcd cluster. This must be generated for every new etcd cluster.

  Enter a value
```
Note that in order to initialize the etcd cluster, the `etcd_discovery_url` variable needs to be assigned a value obtained from https://discovery.etcd.io/new?size=N, where `N` is the number of etcd nodes in the cluster.

Once Terraform completes the provisioning operation, the `kubeconfig` data of the new Kubernetes cluster will be output. Copy its content into your `kubeconfig` file, and then verify that the cluster is healthy:
```sh
$ kubectl --kubeconfig=<your_kubeconfig_file> get componentstatuses
NAME                 STATUS    MESSAGE              ERROR
scheduler            Healthy   ok
controller-manager   Healthy   ok
etcd-0               Healthy   {"health": "true"}
etcd-2               Healthy   {"health": "true"}
etcd-1               Healthy   {"health": "true"}

$ kubectl --kubeconfig=<your_kubeconfig_file> get no
NAME            STATUS    AGE       VERSION
k8s-worker-00   Ready     44s       v1.7.0
k8s-worker-01   Ready     46s       v1.7.0
k8s-worker-02   Ready     48s       v1.7.0
```

A bearer token which can be included in the `Authorization` header of HTTP requests will also be output. For example,
```sh
$ curl --cacert <cacert> https://<k8s_master_public_ip>:6443/version
Unauthorized
$ curl --cacert <cacert> -H "Authorization: Bearer <token>" https://<public_ip>:6443/version
{
  "major": "1",
  "minor": "7",
  "gitVersion": "v1.7.0",
  "gitCommit": "d3ada0119e776222f11ec7945e6d860061339aad",
  "gitTreeState": "clean",
  "buildDate": "2017-06-29T22:55:19Z",
  "goVersion": "go1.8.3",
  "compiler": "gc",
  "platform": "linux/amd64"
}
```
Note that the base64-encoded CA cert can be obtained from the `kubeconfig` output.

## Cluster Layout
By default, this project provisions a cluster that is comprised of:

* 3 etcd3 droplets
* 1 Kubernetes Master droplet and
* 3 Kubernetes Workers droplets

All droplets are initialized using CoreOS' [Container Linux Config](https://coreos.com/os/docs/latest/provisioning.html). These configurations are defined in the `config.yaml` files found in the `etcd/` and `k8s/` folders. They are interpolated using the Terraform's Config Transpiler provider.

[CoreDNS](https://coredns.io/tags/documentation/) is used to provide droplet-level hostname resolution.

**Note that this setup uses the Terraform [TLS Provider](https://www.terraform.io/docs/providers/tls/index.html) to generate RSA private keys, CSR and certificates for development purposes only. The resources generated will be saved in the Terraform state file as plain text. Make sure the Terraform state file is stored securely.**

### etcd3
The number of etcd3 instances provisioned in the cluster can be altered using the `etcd_count` Terraform variable.

The etcd3 cluster is only accessible by nodes which are part of the cluster. All peer-to-peer and client-to-server communications are encrypted and authenticated using the self-signed CA, private key and TLS certificate.

Every etcd instance's data directory (defaulted to `/var/lib/etcd`) is mounted as a volume to a [DigitalOcean block storage](https://www.digitalocean.com/products/storage/).

For testing purposes, the `etcdctl` v2 client on every etcd droplet is configured to target the etcd cluster. For example,
```sh
$ doctl compute ssh etcd-00
Last login: <redacted>
Container Linux by CoreOS stable (1465.7.0)

$ etcdctl cluster-health
member 1ac8697e1ee7cb22 is healthy: got healthy result from https://xx.xxx.xxx.xxx:xxxx
member 8e62221f3a6bf84d is healthy: got healthy result from https://xx.xxx.xxx.xxx:xxxx
member 9350aa2a45b92d34 is healthy: got healthy result from https://xx.xxx.xxx.xxx:xxxx
cluster is healthy
```

### Kubernetes
The following componenets are deployed in the Kubernetes cluster:

* Kubernetes Master: kube-apiserver, kube-controller-manager, kube-scheduler
* Kubernetes Workers: kubelet, kube-proxy

The number of Kubernetes workers can be altered using the `k8s_workers_count` Terraform variable.

The API Server is started with the following admission controllers:

1. NamespaceLifecycle
1. LimitRanger
1. ServiceAccount
1. PersistentVolumeLabel
1. DefaultStorageClass
1. ResourceQuota
1. DefaultTolerationSeconds
1. NodeRestriction

All API requests to the API Server are authenticated using X.509 TLS certificates and static bearer tokens. (To disable [anonymous requests](https://kubernetes.io/docs/admin/authentication/#anonymous-requests), the API Server is started with the `--anonymous-auth=false` flag.) Refer to the Kubernetes [_Authentication_](https://kubernetes.io/docs/admin/authentication/) documentation for more information on these authentication strategies.

Use the `k8s/master/token.csv` file to add more bearer token. The access rights of the corresponding users are specified in the `k8s/master/abac.json` file.

All communications between the API Server, etcd, Kubelet and clients such as Kubectl are secured with TLS certs. The certificates and private keys are declared in the `k8s-master.tf` and `k8s-workers` files. The CSRs used to generate the certificate are also found in the same files. Since the Controller Manager and Scheduler resides on the same host as the API Server, they can communicate with the API Server via its insecure network interface.

The Controller Manager uses the CA cert and key declared in `ca.tf` to serve cluster-scoped certificates-issuing requests. Refer to the [Master Node Communication docs](http://kubernetes.io/docs/admin/master-node-communication/#controller-manager-configuration) for details.

## Add-ons
All add-ons are deployed using [Helm charts](https://helm.sh/).

## Droplet Updates
CoreOS [locksmith](https://github.com/coreos/locksmith) is enabled to perform updates on Container Linux. By default, `locksmithd` is configured to use the `etcd-lock` reboot strategy during updates. The reboot window is set to a 2 hour window starting at 1 AM on Sundays.

The following Terraform variables can be used to configure the reboot strategy and maintenance window:

* `droplet_maintenance_window_start`
* `droplet_maintenance_window_length`
* `droplet_update_channel`

The default update group is `stable`.

For more information, refer to the Container Linux documentation on [Update Strategies](https://coreos.com/os/docs/1506.0.0/update-strategies.html).

## License
See the [LICENSE](LICENSE) file for the full license text.

## References

* [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way)
* [Running etcd on Container Linux](https://coreos.com/etcd/docs/latest/getting-started-with-etcd.html)
* [Container Linux Config Spec](https://coreos.com/os/docs/1506.0.0/configuration.html)
* [CoreDNS](https://coredns.io/tags/documentation/)
* [How To Install And Configure Kubernetes On Top Of A CoreOS Cluster](https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-kubernetes-on-top-of-a-coreos-cluster)
* [CoreOS + Kubernetes Step By Step](https://coreos.com/kubernetes/docs/latest/getting-started.html)
* [Kubernetes API Authentication](https://kubernetes.io/docs/admin/authentication/)
* [Kubernetes API Authorization](https://kubernetes.io/docs/admin/authorization/)
