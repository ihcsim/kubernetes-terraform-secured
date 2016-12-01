# kubernetes-terraform-secured

This project shows you how to deploy a secured Kubernetes cluster on DigitalOcean. The instructions here are based on [Kelsey Hightower's _Kubernetes The Hard Way_](https://github.com/kelseyhightower/kubernetes-the-hard-way). Terraform v0.7.10 is used to automate the cluster deployment.

## Table of Content

* [Getting Started](#getting-started)
* [Known Issues](#known-issues)
* [Service Management](#service-management)
* [TLS](#tls)
* [Authentication](#authentication)
* [Authorization](#authorization)
* [DNS](#dns)

## Getting Started

**Note that the droplets created as part of this tutorial aren't free.**

By default, the cluster is comprised of 3 etcd instances, 1 Kubernetes Master and 2 Kubernetes Workers.

Prior to running Terraform to set up the cluster, create a copy of the `terraform.tfvars` file based on the provided `terraform.tfvars.sample` file. In particular, the following variables will be of special interest:

Variables            | Description
------------------   | -----------
`etcd_count`         |
`k8s_worker_count`   |
`etcd_discovery_url` | **A new service discovery URL must be obtained from [here](https://discovery.etcd.io/new?size=3) everytime a new cluster is created.**

Once all the required variables are provided, run:
```sh
$ terraform apply
```

If succeeded, the droplets' name and public addresses will be output:
```sh
...
Apply complete! Resources: 25 added, 0 changed, 0 destroyed.

The state of your infrastructure has been saved to the path
below. This state is required to modify and destroy your
infrastructure, so keep it safe. To inspect the complete state
use the `terraform show` command.

State path: terraform.tfstate

Outputs:

Kubernetes Master = https://xxx.xxx.xxx.xxx:xxxx
etcd = [
    https://xxx.xxx.xxx.xxx:xxxx,
    https://xxx.xxx.xxx.xxx:xxxx,
    https://xxx.xxx.xxx.xxx:Xxxx
]
```

To verify that the etcd cluster is accessible from an external host, run the following command:
```sh
$ etcdctl --endpoints https://<etcd-00-public-ip>:xxxx,https://<etcd-01-public-ip>:xxxx,https://<etcd-02-public-ip>:xxxx \
          --cert-file <your-cert> \
          --key-file <your-key> \
          --ca-file <your-ca-cert>
          cluster-health
member fec6653bf64f68d is healthy: got healthy result from https://<etcd-00-public-ip>:xxxx
member 4e62ba9090bc7797 is healthy: got healthy result from https://<etcd-01-public-ip>:xxxx
member b5b0591f9b16568b is healthy: got healthy result from https://<etcd-02-public-ip>:xxxx
cluster is healthy
```
The `etcdctl` client on each droplet within the cluster is pre-configured to target the private network interfaces and employ the correct TLS certs and keys for secure inter-cluster communication.

To verify that the Kubernetes cluster is accessible from an external host, run the following `curl` command:
```sh
$ curl --cacert <your-ca-cert> \
       --key <your-client-key> \
       --cert <your-cert> \
       https://<k8s-master-public-ipv4>:<k8s-apiserver-secure-port>
{
  "paths": [
    "/api",
    "/api/v1",
    "/apis",
    "/apis/apps",
    "/apis/apps/v1alpha1",
    "/apis/authentication.k8s.io",
    "/apis/authentication.k8s.io/v1beta1",
    "/apis/authorization.k8s.io",
    "/apis/authorization.k8s.io/v1beta1",
    "/apis/autoscaling",
    "/apis/autoscaling/v1",
    "/apis/batch",
    "/apis/batch/v1",
    "/apis/batch/v2alpha1",
    "/apis/certificates.k8s.io",
    "/apis/certificates.k8s.io/v1alpha1",
    "/apis/extensions",
    "/apis/extensions/v1beta1",
    "/apis/policy",
    "/apis/policy/v1alpha1",
    "/apis/rbac.authorization.k8s.io",
    "/apis/rbac.authorization.k8s.io/v1alpha1",
    "/apis/storage.k8s.io",
    "/apis/storage.k8s.io/v1beta1",
    "/healthz",
    "/healthz/ping",
    "/logs",
    "/metrics",
    "/swagger-ui/",
    "/swaggerapi/",
    "/ui/",
    "/version"
  ]
}
```

You can also set up `kubectl` to target your Kubernetes cluster by using the following commands:
```sh
$ kubectl config set-cluster do-k8s \
          --server=https://<k8s-master-public-ipv4>:<k8s-apiserver-secure-port> \
          --certificate-authority=<your-ca-cert>
$ kubectl config set-credentials cluster-admin \
          --client-certificate=<your-client-cert> \
          --client-key=<your-client-key>
$ kubectl config set-context do-k8s --cluster=do-k8s --user=cluster-admin
$ kubectl config use-context do-k8s
$ kubectl cluster-info
Kubernetes master is running at https://xxx.xxx.xxx.xxx:xxxx

To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.
$ kubectl get cs
NAME                 STATUS      MESSAGE                                                               ERROR
scheduler            Healthy     ok
controller-manager   Healthy     ok
etcd-0               Unhealthy   Get https://xxx.xxx.xxx.xxx:xxxx/health: remote error: bad certificate
etcd-2               Unhealthy   Get https://xxx.xxx.xxx.xxx:xxxx/health: remote error: bad certificate
etcd-1               Unhealthy   Get https://xxx.xxx.xxx.xxx:xxxx/health: remote error: bad certificate

$ kubectl get nodes
xxx.xxx.xxx.xxx    Ready      6m
xxx.xxx.xxx.xxx    Ready      6m
```

Test the Kubernetes cluster further by deploying some applications to it:
```sh
$ kubectl create -f apps/ticker/deployment
$ kubectl get po
NAME                      READY     STATUS    RESTARTS   AGE
ticker-1710468970-bv30t   1/1       Running   0          13m
ticker-1710468970-tnvls   1/1       Running   0          13m
$ kubectl logs ticker-1710468970-bv30t
837: Thu Dec  1 04:24:19 UTC 2016
838: Thu Dec  1 04:24:20 UTC 2016
839: Thu Dec  1 04:24:21 UTC 2016
840: Thu Dec  1 04:24:22 UTC 2016
841: Thu Dec  1 04:24:23 UTC 2016
842: Thu Dec  1 04:24:24 UTC 2016
843: Thu Dec  1 04:24:25 UTC 2016
844: Thu Dec  1 04:24:26 UTC 2016
845: Thu Dec  1 04:24:27 UTC 2016
846: Thu Dec  1 04:24:28 UTC 2016
847: Thu Dec  1 04:24:29 UTC 2016
848: Thu Dec  1 04:24:30 UTC 2016
849: Thu Dec  1 04:24:31 UTC 2016
850: Thu Dec  1 04:24:32 UTC 2016
851: Thu Dec  1 04:24:33 UTC 2016
852: Thu Dec  1 04:24:34 UTC 2016
853: Thu Dec  1 04:24:35 UTC 2016
854: Thu Dec  1 04:24:36 UTC 2016

$ kubectl run nginx --image=nginx --port=80 --replicas=3
$ kubectl get po -o wide
NAME                      READY     STATUS    RESTARTS   AGE       IP           NODE
nginx-3449338310-7quja    1/1       Running   0          16m       10.200.0.3   10.138.48.74
nginx-3449338310-m4mlv    1/1       Running   0          16m       10.200.1.3   10.138.208.238
nginx-3449338310-q9lj5    1/1       Running   0          16m       10.200.0.4   10.138.48.74
$ kubectl expose deployment nginx --type NodePort
$ NODE_PORT=`kubectl get svc nginx --output=jsonpath='{range .spec.ports[0]}{.nodePort}'`
$ curl http://<k8s_worker_public_ip>:$NODE_PORT # will have to find out which worker the pod is on
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to nginx!</h1>
<p>If you see this page, the nginx web server is successfully installed and
working. Further configuration is required.</p>

<p>For online documentation and support please refer to
<a href="http://nginx.org/">nginx.org</a>.<br/>
Commercial support is available at
<a href="http://nginx.com/">nginx.com</a>.</p>

<p><em>Thank you for using nginx.</em></p>
</body>
</html>

$ kubectl create -f apps/guestbook/redis.yml
$ kubectl create -f apps/guestbook/frontend.yml
$ curl http://<k8s_worker_public_ip>:32100/
<html ng-app="redis">
  <head>
    <title>Guestbook</title>
    <link rel="stylesheet" href="//netdna.bootstrapcdn.com/bootstrap/3.1.1/css/bootstrap.min.css">
    <script src="https://ajax.googleapis.com/ajax/libs/angularjs/1.2.12/angular.min.js"></script>
    <script src="controllers.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/angular-ui-bootstrap/0.13.0/ui-bootstrap-tpls.js"></script>
  </head>
  <body ng-controller="RedisCtrl">
    <div style="width: 50%; margin-left: 20px">
      <h2>Guestbook</h2>
    <form>
    <fieldset>
    <input ng-model="msg" placeholder="Messages" class="form-control" type="text" name="input"><br>
    <button type="button" class="btn btn-primary" ng-click="controller.onRedis()">Submit</button>
    </fieldset>
    </form>
    <div>
      <div ng-repeat="msg in messages track by $index">
        {{msg}}
      </div>
    </div>
    </div>
  </body>
</html>
```

## Known Issues

At the time of this writing, the following is a list of [known Kubernetes issue] seen in our error logs:

1. [35773](https://github.com/kubernetes/kubernetes/issues/35773) where the etcd instances are reported as unhealthy when the `client-cert-auth` option is enabled.
1. [22586](https://github.com/kubernetes/kubernetes/issues/22586) where the kubelet's logs show a `conversion.go:128 failed to handle multiple devices for container. Skipping Filesystem stats` error message.
1. [26000](https://github.com/kubernetes/kubernetes/issues/26000) where the kubelet's image garbage collection failed.

## Service Management
The Kubernetes cluster and all the supporting services (docker, [etcd](https://github.com/coreos/etcd), [fleet](https://github.com/coreos/fleet), [flannel](https://github.com/coreos/flannel) and [locksmith](https://github.com/coreos/locksmith)) are managed by [systemd](https://www.freedesktop.org/wiki/Software/systemd/) on CoreOS. The [cloud-config](https://coreos.com/os/docs/latest/cloud-config.html) files used to declare these services are found in the `etcd/` and `k8s/` folders.

## TLS
**This set-up uses the Terraform [TLS Provider](https://www.terraform.io/docs/providers/tls/index.html) to generate RSA private keys, CSR and certificates for development purposes only. The resources generated will be saved in the Terraform state file as plain text. Make sure the Terraform state file is stored securely.**

### Certificate Authority

The CA cert used to sign all the cluster SSL/TLS certificates are declared in the `ca.tf` file.

### etcd

All client-to-server and peer-to-peer communication for the etcd cluster are secured by the TLS certificate declared as the `etcd_cert` resource in the `etcd.tf` file. The private key and CSR used to generate the certificate are also found in the same file. All etcd instances listen to their peers on their respective host's private IP address. Clients such as `etcdctl` can connect to the cluster via both public and private network interfaces. In the current set-up, the etcd cluster uses the same certificate for all client-to-server and peer-to-peer communication. In a production environment, it is encouraged to use different certs for these different purposes.

### Kubernetes

All communication between the API Server, etcd, Kubelet and clients such as Kubectl are secured with TLS certs. The certificate is declared as the `k8s_cert` resource in the `k8s.tf` file. The private key and CSR used to generate the certificate are also found in the same file. Since the Controller Manager and Scheduler resides on the same host as the API Server, they commuicate with the API Server via its insecure network interface.

Also, the Controller Manager uses the CA cert and key declared in `ca.tf` to serve cluster-scoped certificates-issuing requests. Refer to the [Master Node Communication docs](http://kubernetes.io/docs/admin/master-node-communication/#controller-manager-configuration) for details.

## Authentication
In this set-up, the Kubernetes API Server is configured to authenticate incoming API requests using the client's X509 certs and a static token file. Per the Kubernetes [authentication docs](http://kubernetes.io/docs/admin/authentication/#authentication-strategies), the first authentication module to successfully authenticate the client's request will short-circuit the evaluation process.

The CA cert that is used to sign the client's cert is passed to the API Server using the `--client-ca-file=SOMEFILE` option. This configuration is found in the `k8s/master/unit-files/kube-apiserver.service` unit file. A client (such as `kubectl`) authenticates with the API Server by providing its cert and private key as command line options as seen in the above `kubectl` command example. For more information on the Kubernetes x509 client cert authentication strategy, refer to the docs [here](http://kubernetes.io/docs/admin/authentication/#x509-client-certs).

The API server is also set up to read bearer tokens from the file specified as the `--token-auth-file=SOMEFILE` option. This configuration is found in the `k8s/master/unit-files/kube-apiserver.service` unit file. The template of the token file can be found in the `k8s/master/auth/token.csv` file. The tokens for the two predefined users (`admin` and `kubelet`) are specified using the variables `k8s_apiserver_token_admin` and `k8s_apiserver_token_kubelet`, respectively. A client (such as `kubectl`) can authenticate with the API Server by putting the bearer token in its HTTP Header in the form of:
```
Authorization: Bearer 31ada4fd-adec-460c-809a-9e56ceb7526
```
For more information on the bearer token authentication strategy, refer to the docs [here](http://kubernetes.io/docs/admin/authentication/#static-token-file).

The Kubelet authenticates with the API Server using the token-based approach, where the `kubelet` user's token is specified in the Kubelet's `kubeconfig` file.

The Controller Manager uses the RSA private key `k8s_key` to sign any bearer tokens for all new non-default service accounts. The resource for this key is declared in the `k8s.tf` file.

## Authorization
HTTP requests sent to the API Server's secure port are authorized using the [_Attribute-Based Access COntrol_ (ABAC)](http://kubernetes.io/docs/admin/authorization/) authorization scheme. The authorization policy file is provided to the API Server using the `--authorization-policy-file=SOMEFILE` option as seen in the `k8s/master/unit-files/kube-apiserver.service` unit file.

In this set-up, 5 policy objects are provided; one policy for each user defined in the `k8s/master/auth/token.csv` file, one `*` policy and one service account policy. The `admin`, `scheduler` and `kubelet` users are authorized to access all resources (such as pods) and API groups (such as `extensions`) in all namespaces. Non-resource paths (such as `/version` and `/apis`) are read-only accessible by any users. The service account group has access to all resources, API groups and non-resource paths in all namespaces.

## Networking
Flannel
Kubernetes network plugin

## DNS

## LICENSE

See the [LICENSE](LICENSE) file for the full license text.
