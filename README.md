# kubernetes-terraform-secured

This project uses [Terraform](https://www.terraform.io/) to provision [Kubernetes](https://kubernetes.io/) on [DigitalOcean](https://www.digitalocean.com/), with [Container Linux](https://coreos.com/os/docs/latest).

**Note that the droplets and volumes created as part of this tutorial aren't free.**

## Table of Content

* [Getting Started](#getting-started)
* [Cluster Layout](#cluster-layout)
  * [etcd3](#etcd3)
  * [Kubernetes](#kubernetes)
    * [Authentication](#authentication)
    * [Authorization](#authorization)
    * [Admission Control](#admission-control)
    * [Network](#network)
    * [DNS](#dns)
* [Add-ons](#add-ons)
* [Droplet Updates](#droplet-updates)
* [License](#license)
* [References](#references)

## Prerequisites

* [Terraform v0.10.0](https://www.terraform.io/downloads.html)
* [Container Linux Config Transpiler Provider](https://github.com/coreos/terraform-provider-ct)
* [Go 1.8.3](https://golang.org/dl/)

## Getting Started
To get started, clone this repository. Then use the following Terraform commands to initialize the project and provision the Kubernetes cluster. At the time of this writing, the Linux Container's Config Transpiler provider hasn't been included in the official [Terraform Providers repository](https://github.com/terraform-providers). Hence, it will need to be copied into your local `kubernetes-terraform-secured/.terraform` folder.

Clone this repository:
```sh
$ git clone git@github.com:ihcsim/kubernetes-terraform-secured.git
```

Initialize the project:
```sh
$ terraform init
```

The above command will fail with errors complaining about the missing Config Transpiler provider. Install the Config Transpiler provider:
```sh
$ cd kuberntes-terraform-secured
$ go get -u github.com/coreos/terraform-provider-ct
$ cp $GOPATH/bin/terraform-provider-ct .terraform/plugins/<os_arch>/
```

Re-initialize the project:
```sh
$ terraform init
```

Create a copy of the `terraform.tfvars` file from the provided `terraform.tfvars.sample` file. Provide all the required values. The description of all these variables can be found in the `vars.tf` file.

Provision the Kubernetes cluster using the following Terraform command. In order to set up the etcd cluster, the `etcd_discovery_url` variable needs to be assigned a value obtained from https://discovery.etcd.io/new?size=N, where `N` is the number of etcd nodes in the cluster.
```sh
$ terraform apply
var.etcd_discovery_url
  Discovery URL obtained from https://discovery.etcd.io/new?size=N where N is the size of the etcd cluster. This must be generated for every new etcd cluster.

  Enter a value
```

Once Terraform successfully completed the provisioning operation, the `kubeconfig` data of the new Kubernetes cluster will be output. Copy its content into your `kubeconfig` file, and then verify the cluster's accessibility.
```sh
$ kubectl --kubeconfig=<your_kubeconfig_file> get componentstatuses
NAME                 STATUS    MESSAGE              ERROR
scheduler            Healthy   ok
controller-manager   Healthy   ok
etcd-0               Healthy   {"health": "true"}
etcd-2               Healthy   {"health": "true"}
etcd-1               Healthy   {"health": "true"}

$ kubectl --kubeconfig=M<your_kubeconfig_file> get no
NAME            STATUS    AGE       VERSION
k8s-worker-00   Ready     44s       v1.7.0
k8s-worker-01   Ready     46s       v1.7.0
k8s-worker-02   Ready     48s       v1.7.0
```

## Cluster Layout
By default, this project provisions a cluster that is comprised of:

* 3 etcd3 nodes
* 1 SkyDNS node
* 1 Kubernetes Master and
* 2 Kubernetes Workers

**This set-up uses the Terraform [TLS Provider](https://www.terraform.io/docs/providers/tls/index.html) to generate RSA private keys, CSR and certificates for development purposes only. The resources generated will be saved in the Terraform state file as plain text. Make sure the Terraform state file is stored securely.**

### etcd3
The number of etcd3 instances in the cluster can be altered by using the `etcd_count` Terraform variable.

The etcd3 cluster is only accessible by nodes within the cluster. All peer-to-peer and client-to-server communication is encrypted and authenticated by using self-signed CA, private key and TLS certificate. These self-signed TLS artifacts are generated using the [Terraform TLS provider](https://www.terraform.io/docs/providers/tls/index.html).

Every etcd instance's `data-dir` at `/var/lib/etcd` is mounted as a volume to a [DigitalOcean block storage](https://www.digitalocean.com/products/storage/).

On every droplet, the `etcdctl` v2 client is configured to target the etcd cluster.
```sh
$ etcdctl cluster-health
member 1ac8697e1ee7cb22 is healthy: got healthy result from https://xx.xxx.xxx.xxx:xxxx
member 8e62221f3a6bf84d is healthy: got healthy result from https://xx.xxx.xxx.xxx:xxxx
member 9350aa2a45b92d34 is healthy: got healthy result from https://xx.xxx.xxx.xxx:xxxx
cluster is healthy
```

All client-to-server and peer-to-peer communication for the etcd cluster are secured by the TLS certificate and private key declared in the `etcd.tf` file. The CSR used to generate the certificate are also found in the same file. All etcd instances listen to their peers on their respective host's private IP address. Clients such as `etcdctl` can connect to the cluster via both public and private network interfaces. In the current set-up, the etcd cluster uses the same certificate for all client-to-server and peer-to-peer communication. In a production environment, it is encouraged to use different certs for these different purposes.

### Kubernetes
All communication between the API Server, etcd, Kubelet and clients such as Kubectl are secured with TLS certs. The certificate and private key are declared in the `k8s-master.tf` and `k8s-workers` files. The CSR used to generate the certificate are also found in the same files. Since the Controller Manager and Scheduler resides on the same host as the API Server, they communicate with the API Server via its insecure network interface.

Also, the Controller Manager uses the CA cert and key declared in `ca.tf` to serve cluster-scoped certificates-issuing requests. Refer to the [Master Node Communication docs](http://kubernetes.io/docs/admin/master-node-communication/#controller-manager-configuration) for details.

#### Authentication
In this set-up, the Kubernetes API Server is configured to authenticate incoming API requests using the client's X509 certs, a static token file and a Basic authentication password file. Per the Kubernetes [authentication docs](http://kubernetes.io/docs/admin/authentication/#authentication-strategies), the first authentication module to successfully authenticate the client's request will short-circuit the evaluation process.

The CA cert that is used to sign the client's cert is passed to the API Server using the `--client-ca-file=SOMEFILE` option. This configuration is found in the `k8s/master/unit-files/kube-apiserver.service` unit file. A client (such as `kubectl`) authenticates with the API Server by providing its cert and private key as command line options as seen in the above `kubectl` command example. For more information on the Kubernetes x509 client cert authentication strategy, refer to the docs [here](http://kubernetes.io/docs/admin/authentication/#x509-client-certs).

The API server is also set up to read bearer tokens from the file specified as the `--token-auth-file=SOMEFILE` option. This configuration is found in the `k8s/master/unit-files/kube-apiserver.service` unit file. The template of the token file can be found in the `k8s/master/auth/token.csv` file. The tokens for the two predefined users (`admin` and `kubelet`) are specified using the variables `k8s_apiserver_token_admin` and `k8s_apiserver_token_kubelet`, respectively. A client (such as `kubectl`) can authenticate with the API Server by putting the bearer token in its HTTP Header in the form of:
```
Authorization: Bearer 31ada4fd-adec-460c-809a-9e56ceb7526
```
For more information on the bearer token authentication strategy, refer to the docs [here](http://kubernetes.io/docs/admin/authentication/#static-token-file).

The `k8s/master/auth/basic` file contains the Basic authentication password for the `admin` user, used to access the cluster UI at `https://<k8s-master-public-ip>:<secure-port>/ui`. The password value can be specified using the `k8s_apiserver_basic_auth_admin` variable.

The Kubelet authenticates with the API Server using the token-based approach, where the `kubelet` user's token is specified in the Kubelet's `kubeconfig` file. The template for this `kubeconfig` file can be found in the `k8s/workers` folder.

The Controller Manager uses the RSA private key `k8s_key` to sign any bearer tokens for all new non-default service accounts. The resource for this key is declared in the `k8s.tf` file.

#### Authorization
HTTP requests sent to the API Server's secure port are authorized using the [_Attribute-Based Access Control_ (ABAC)](http://kubernetes.io/docs/admin/authorization/) authorization scheme. The authorization policy file is provided to the API Server using the `--authorization-policy-file=SOMEFILE` option as seen in the `k8s/master/unit-files/kube-apiserver.service` unit file.

In this set-up, 4 policy objects are provided; one policy for each user defined in the `k8s/master/auth/token.csv` file, one `*` policy and one service account policy. The `admin` and `kubelet` users are authorized to access all resources (such as pods) and API groups (such as `extensions`) in all namespaces. Non-resource paths (such as `/version` and `/apis`) are read-only accessible by any users. The service account group has access to all resources, API groups and non-resource paths in all namespaces.

#### Admission Control
As [recommended](http://kubernetes.io/docs/admin/admission-controllers/#is-there-a-recommended-set-of-plug-ins-to-use), the API Server is started with the following admission controllers:

1. NamespaceLifecycle
1. LimitRanger
1. ServiceAccount
1. DefaultStorageClass
1. ResourceQuota

This configuration is defined in the `k8s/master/unit-files/kube-apiserver` unit file.

#### Network
[Flannel](https://github.com/coreos/flannel) is used to provide an overlay network to support cross-node traffic among pods. The Pod IP range is defined by the `k8s_cluster_cidr` variable. I attempted to run the Flannel CNI plugin as described [here](https://github.com/containernetworking/cni/blob/master/Documentation/flannel.md), using the bits from https://storage.googleapis.com/kubernetes-release/network-plugins/cni-07a8a28637e97b22eb8dfe710eeae1344f69d16e.tar.gz. It looks like the only way to get this to work at the time of this writing is to set up the Flannel CNI to delegate to Calico, as detailed in the CoreOS's [docs](https://coreos.com/kubernetes/docs/latest/deploy-master.html#set-up-the-cni-config-optional).

#### DNS
[KubeDNS](https://github.com/kubernetes/kubernetes/tree/master/cluster/addons/dns) is deployed to enable cluster DNS. The corresponding service and deployment definitions are found in the `apps.tf` file. In order for Heapster and the guestbook-go apps to work, the inter-pods DNS resolution must be available. The FQDN of all Kubernetes services are suffixed with the domain name defined by the `k8s_cluster_domain` variable.

A standalone instance of [SkyDNS](https://github.com/skynetservices/skydns) is deployed to enable droplet-level DNS service announcement and resolution, under the service name `skydns`. The resource that defines the droplet is found in the `dns.tf` script. It shares the same etcd instances with Kubernetes. The `/etc/systemd/resolv.conf.d/droplet.conf` configuration file of all the droplets contain reference to this nameserver. The FQDN of all the droplets is suffixed with the domain name defined by the `droplet_domain` variable.

You can use `dig` to test the droplets DNS resolution:
```sh
$ dig @skydns SRV any.coreos.local

; <<>> DiG 9.10.2-P4 <<>> @skydns SRV any.coreos.local
; (1 server found)
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 10317
;; flags: qr aa rd ra; QUERY: 1, ANSWER: 7, AUTHORITY: 0, ADDITIONAL: 7

;; QUESTION SECTION:
;any.coreos.local.		IN	SRV

;; ANSWER SECTION:
any.coreos.local.	3600	IN	SRV	10 14 0 k8s-worker-01.coreos.local.
any.coreos.local.	3600	IN	SRV	10 14 0 k8s-worker-00.coreos.local.
any.coreos.local.	3600	IN	SRV	10 14 0 k8s-master.coreos.local.
any.coreos.local.	3600	IN	SRV	10 14 0 skydns.coreos.local.
any.coreos.local.	3600	IN	SRV	10 14 0 etcd-02.coreos.local.
any.coreos.local.	3600	IN	SRV	10 14 0 etcd-00.coreos.local.
any.coreos.local.	3600	IN	SRV	10 14 0 etcd-01.coreos.local.

;; ADDITIONAL SECTION:
k8s-worker-01.coreos.local. 3600 IN	A	xx.xxx.xxx.xxx
k8s-worker-00.coreos.local. 3600 IN	A	xx.xxx.xxx.xxx
k8s-master.coreos.local. 3600	IN	A	xx.xxx.xxx.xxx
skydns.coreos.local.	3600	IN	A	xx.xxx.xxx.xxx
etcd-02.coreos.local.	3600	IN	A	xxx.xxx.xxx.xxx
etcd-00.coreos.local.	3600	IN	A	xxx.xxx.xxx.xxx
etcd-01.coreos.local.	3600	IN	A	xxx.xxx.xxx.xxx

;; Query time: 3 msec
;; SERVER: xxx.xxx.xxx.xxx#xx(xxx.xxx.xxx.xxx)
;; WHEN: Sun Dec 11 05:07:30 UTC 2016
;; MSG SIZE  rcvd: 356
```

## Add-ons
After the `k8s-master` droplet is created, the `apps.tf` script deploys KubeDNS, Kubernetes Dashboard and Heapster (back by InfluxDB and Grafana) to the cluster. It might take a few minutes after the pods deployment for the resource monitoring graphs to show up.

The Kubernetes Dashboard and Swagger UI are accessible using a web browser at `https://<k8s-master-public-ip>:6443/ui` and `https://<k8s-master-public-ip>/swagger-ui`, respectively. The default basic username is `admin`, with the password specified by the `k8s.apiserver_basic_auth_admin` variable. Note that your web browser will likely generate some certificate-related warnings, complaining that the certificates aren't trusted. This is expected since the TLS certifcates are signed by a self-generated CA.

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
* [How To Install And Configure Kubernetes On Top Of A CoreOS Cluster](https://www.digitalocean.com/community/tutorials/how-to-install-and-configure-kubernetes-on-top-of-a-coreos-cluster)
* [CoreOS + Kubernetes Step By Step](https://coreos.com/kubernetes/docs/latest/getting-started.html).
