# Day 4 — Backup, Upgrade & Restore

Welcome to Day 4. Today we cover three operational tasks that keep a cluster healthy and recoverable:

- **Backup** — capturing a namespace (workloads, secrets, and volume data) with GKE Backup
- **Upgrade** — moving the control plane and node pools to a new Kubernetes version safely
- **Restore** — recovering from a disaster by restoring the namespace from a backup

> The **GKE Backup add-on** (`gke_backup_agent_config` in `cluster.tf`) and the **backup plan**
> (`google_gke_backup_backup_plan` in `cluster.tf`) are already defined in Terraform. Today is about
> *using* them.

## Taking a backup

We use the GKE Backup add-on. It is enabled with a single block in `cluster.tf`:

```hcl
addons_config {
  gke_backup_agent_config { enabled = true }
}
```

With the agent enabled, you need a **backup plan** — the policy that says *what* to back up and *how
often*. Look at `cluster.tf`: the `app-daily` plan backs up the `app` namespace daily at 02:00, and
sets `include_volume_data = true` (captures any PersistentVolume data) and `include_secrets = true`
(captures the namespace's `Secret` objects).

> **Note on this app's state.** Online Boutique is effectively stateless — its only stateful
> component, `redis-cart`, uses an `emptyDir` volume, not a PersistentVolumeClaim. So there's no
> persistent volume for `include_volume_data` to snapshot here; the meaningful artifact is the set of
> namespace resources (Deployments, Services, the Ingress, ServiceAccounts, Secrets). The volume-data
> options are left enabled so the plan keeps working unchanged if you later add a workload backed by a
> real PVC.

For testing we'll trigger a backup manually rather than wait for the schedule:

```bash
export PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
gcloud beta container backup-restore backups create backup-manual \
  --project=$PROJECT_ID --location=us-central1 --backup-plan=app-daily
```

Verify the backup was created:

```bash
gcloud beta container backup-restore backups list \
  --project=$PROJECT_ID --location=us-central1
```

## Upgrading the cluster

First note the current control plane and node versions, so you have a before/after reference:

```bash
gcloud container clusters describe gke-test --region us-central1 \
  --format='value(currentMasterVersion, currentNodeVersion)'
```

In this walkthrough the control plane and nodes start on `1.35.3-gke.199300`.

Check which versions are available to upgrade to:

```bash
gcloud container get-server-config --region us-central1 \
  --format='yaml(validMasterVersions, channels)'
```

We'll upgrade to `1.36.0-gke.2253000`.

> **Always upgrade the control plane first, then the node pools.** The control plane must be at or
> ahead of the node version; nodes may not run a newer version than the control plane.

### Control plane

```bash
gcloud container clusters upgrade gke-test --master \
  --cluster-version 1.36.0-gke.2253000 --region us-central1
```

### Node pools

Node pool upgrades follow the **surge** strategy defined in `node_pool.tf`, which keeps capacity up
during the rollout by adding a new node before draining an old one:

```hcl
upgrade_settings {
  strategy        = "SURGE"
  max_surge       = 1 # add 1 EXTRA new-version node before draining an old one
  max_unavailable = 0 # never let an old node go down before its replacement is Ready
}
```

Upgrade the **system** node pool first. Check the current version, upgrade, then confirm:

```bash
kubectl get nodes -l cloud.google.com/gke-nodepool=system -o wide
gcloud container clusters upgrade gke-test --node-pool system \
  --cluster-version 1.36.0-gke.2253000 --region us-central1
kubectl get nodes -l cloud.google.com/gke-nodepool=system -o wide
```

Then upgrade the **general** node pool the same way:

```bash
kubectl get nodes -l cloud.google.com/gke-nodepool=general -o wide
gcloud container clusters upgrade gke-test --node-pool general \
  --cluster-version 1.36.0-gke.2253000 --region us-central1
kubectl get nodes -l cloud.google.com/gke-nodepool=general -o wide
```

## Disaster recovery

Now we simulate a disaster and recover from the backup we took earlier.

### Trigger the disaster

Delete the `app` namespace:

```bash
kubectl delete ns app
```

The command will appear to hang while the namespace sits in `Terminating`. This is expected: the
`app` namespace contains an **Ingress**, which provisions a real Google Cloud HTTP(S) Load Balancer
(forwarding rules, backend services, and **NEGs**). GKE must deprovision all of those GCP resources
before it releases the finalizers and removes the namespace. This typically takes a few minutes.

You can watch the teardown — the Ingress clears first, then the NEG (the last straggler):

```bash
kubectl get ingress -n app
kubectl get svcneg -n app
```

Once both report `No resources found`, the namespace is gone:

```bash
kubectl get ns app   # → Error from server (NotFound)
```

> **Do not force-strip the namespace finalizers** to speed this up. Doing so orphans the load
> balancer and NEGs in GCP — they keep running and incurring cost, and you'll have to delete them by
> hand. Let the controller finish the cleanup.

### Restore from the backup

Restoring is two steps. First create a **restore plan** — the reusable recipe that defines *from*
which backup plan, *into* which cluster, *what* namespace, and *how* to handle conflicts and volume
data:

```bash
export LOCATION=us-central1
gcloud beta container backup-restore restore-plans create app-restore-plan \
  --project=$PROJECT_ID --location=$LOCATION \
  --backup-plan=projects/$PROJECT_ID/locations/$LOCATION/backupPlans/app-daily \
  --cluster=projects/$PROJECT_ID/locations/$LOCATION/clusters/gke-test \
  --namespaced-resource-restore-mode=merge-skip-on-conflict \
  --volume-data-restore-policy=restore-volume-data-from-backup \
  --selected-namespaces=app
```

- `merge-skip-on-conflict` recreates anything missing and leaves existing objects untouched. Since
  we deleted the whole namespace, nothing conflicts and everything is recreated.
- `restore-volume-data-from-backup` restores PersistentVolume data from the snapshot. This app has no
  PVCs (`redis-cart` is `emptyDir`), so there's no volume data to bring back — but the flag is the
  one you'd rely on for a stateful workload, and it's harmless here.

Then run a **restore** against that plan, pointing it at the `backup-manual` backup:

```bash
gcloud beta container backup-restore restores create restore-manual \
  --project=$PROJECT_ID --location=$LOCATION \
  --restore-plan=app-restore-plan \
  --backup=projects/$PROJECT_ID/locations/$LOCATION/backupPlans/app-daily/backups/backup-manual
```

Watch it until the state reaches `SUCCEEDED`:

```bash
gcloud beta container backup-restore restores describe restore-manual \
  --project=$PROJECT_ID --location=$LOCATION --restore-plan=app-restore-plan \
  --format='value(state, stateReason)'
```

### Verify the recovery

Confirm the namespace and workloads are back:

```bash
kubectl get all -n app
```

Because the Ingress is restored, GKE provisions a **brand-new load balancer with a new external IP**
(the old one was destroyed during the delete). Give it a few minutes to get an address:

```bash
kubectl get ingress -n app -w
```

Once the Ingress has an IP and the app is serving, the backup → disaster → restore cycle is complete.

## Summary

```
BACKUP   → capture namespace + volumes + secrets   (GKE Backup plan)
UPGRADE  → control plane first, then node pools     (surge strategy)
RESTORE  → restore plan (recipe) + restore (run)    (recreates LB with new IP)
```
