# gke-playbook

The idea behind this project is to learn GKE and Kubernetes for day-2 operations and bridge the gaps
I have in my skills.

It's a hands-on, day-by-day playbook. I run a real microservices app (Google's
[Online Boutique](https://github.com/googlecloudplatform/microservices-demo)) on a GKE cluster
provisioned with Terraform, then each day layer on one operational concern — observability,
security, scaling, backup/restore, and GitOps — the way you'd actually run a cluster in production
rather than just deploy to it.

> **Full disclosure:** I built this project with the help of AI (Claude Code) and Windsurf for
> writing the docs. Although I used AI, I have a full understanding of the project.

## What's in here

| Path | What it is |
| --- | --- |
| `terraform/` | The GKE cluster and supporting Google Cloud resources (node pools, networking, monitoring, SLOs, alerts) as infrastructure-as-code. |
| `k8s-manifest/` | Kubernetes manifests — the Online Boutique app, plus scaling, monitoring, and security policies. This is the folder Argo CD reconciles. |
| `argocd/` | The Argo CD `Application` that makes Git the source of truth for the cluster. |
| `docs/` | The day-by-day walkthrough (the playbook itself). |

## The stack

- **GKE** — the managed Kubernetes cluster, provisioned with **Terraform**.
- **Online Boutique** — the sample microservices workload running in the `app` namespace.
- **Cloud Monitoring / Managed Prometheus / Grafana** — observability, SLOs, and alerting.
- **Argo CD** — GitOps continuous delivery (the cluster is reconciled from this repo).

## Prerequisites

- A Google Cloud project with billing enabled (the Day 0 cluster runs on the free tier where
  possible).
- [`gcloud`](https://cloud.google.com/sdk/docs/install), [`terraform`](https://developer.hashicorp.com/terraform/install)
  (>= 1.5), and [`kubectl`](https://kubernetes.io/docs/tasks/tools/) installed and authenticated
  (`gcloud auth login` / `gcloud auth application-default login`).
- Start with [Day 0](docs/day-0.md): copy `terraform/terraform.tfvars.example` to
  `terraform/terraform.tfvars`, fill in your own values, then `terraform init && terraform apply`.

## The playbook

The project is divided into days; each day adds a new concept on top of the previous one.

- Day 0 — [Foundation](docs/day-0.md) — provision the cluster and deploy the app
- Day 1 — [Observability](docs/day-1.md) — metrics, logs, dashboards, and SLOs
- Day 2 — [Security](docs/day-2.md) — policies and hardening
- Day 3 — [Scaling](docs/day-3.md) — HPA, VPA, and cluster autoscaling
- Day 4 — [Backup, Upgrade & Restore](docs/day-4.md) — GKE Backup and cluster upgrades
- Day 5 — [GitOps with Argo CD](docs/day-5.md) — make the cluster reconcile from Git

## Credits

- [microservices-demo](https://github.com/googlecloudplatform/microservices-demo) — the sample app
  used for the project
