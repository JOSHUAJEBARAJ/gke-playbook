# Day 0 — Foundation

Welcome to Day 0 of the GKE Playbook. Today's aim is to create the base GKE cluster and deploy the
sample application.

The cluster is provisioned with **Terraform**; the code lives in the `terraform/` folder of this
repository.

## Instructions

1. Clone the repository and move into the `terraform` folder:

```bash
git clone https://github.com/JOSHUAJEBARAJ/gke-playbook.git
cd gke-playbook/terraform
```

2. Copy the example variables file and fill in your own values (project ID, authorized IPs, alert
   email). `terraform.tfvars` is gitignored, so your real values stay local:

```bash
cp terraform.tfvars.example terraform.tfvars
# then edit terraform.tfvars
```

3. Initialize Terraform:

```bash
terraform init
```

> This uses **local state** (a `terraform.tfstate` file in the folder). For team use you'd configure
> a remote backend instead — e.g. a GCS bucket via `terraform init -backend-config=...` plus a
> matching `backend "gcs" {}` block in `versions.tf`.

4. Review the plan, then apply:

```bash
terraform apply
```

5. Once it's done, download the kubeconfig:

```bash
gcloud container clusters get-credentials gke-test \
  --region us-central1 \
  --project <PROJECT_ID>
```

6. Deploy the app manifests (run from the repository root):

```bash
kubectl create ns app
kubectl apply -f k8s-manifest/app/app.yaml -n app
```

7. Give the pods a little time to come up and the Ingress to be provisioned:


```
kubectl get pods -n app
```

```
kubectl get ingress -n app
```

> Note down the Ingress IP and use it to access the application.

## Design

- **Networking**: The GKE cluster is deployed in a custom VPC network and uses VPC-native
  networking. All worker nodes are private; outbound internet access goes through a NAT gateway, and
  Google service access is granted via `private_ip_google_access`. The control plane (master) sits
  behind authorized networks, so only authorized IPs can reach the API endpoint.
- **Workload Identity**: Workload Identity is enabled on the cluster, so workloads can access Google
  Cloud APIs without long-lived service-account keys.
- **Node Pools**: A two-pool setup — a `system` pool tainted with `dedicated=system`, and a
  `general` pool for the workloads with autoscaling enabled.

> Note: I initially planned a separate pool for spot instances, but spot isn't supported on the free
> tier, so I've skipped it for now.