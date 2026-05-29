# Day 5 — GitOps with Argo CD

Welcome to Day 5. Today we make the application **GitOps-driven**: instead of running `kubectl apply`
by hand, we make a Git repo the single source of truth and let a controller continuously reconcile
the cluster to match it.

We use **Argo CD** — it watches a repo/path and ensures the live cluster equals what's committed.

> Our manifests already live in this repo under `k8s-manifest/`. Today is about pointing Argo CD at
> them, not rewriting them.

## Installing Argo CD

Argo CD runs in its own namespace (this is **not** the `app` namespace where the workloads live):

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

Wait for the core components to be ready:

```bash
kubectl wait --for=condition=available --timeout=300s \
  deployment/argocd-server deployment/argocd-repo-server -n argocd
```

### Accessing the UI

Get the auto-generated `admin` password:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

Port-forward the server to your machine (no load balancer needed):

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Open **https://localhost:8080** (accept the self-signed cert) and log in as `admin`.


## The Argo CD Application

An **`Application`** is the object that makes Git the source of truth — it says *watch this repo +
path, and make this namespace match it*. Ours lives in `argocd/app-v1.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: onlineboutique
  namespace: argocd            # the Application object lives in argocd, not app
spec:
  project: default
  source:
    repoURL: https://github.com/JOSHUAJEBARAJ/gke-playbook.git
    targetRevision: main
    path: k8s-manifest/app     # the folder Argo CD reconciles
  destination:
    server: https://kubernetes.default.svc
    namespace: app             # where the workloads land
  syncPolicy:
    automated:
      prune: true              # delete resources removed from Git
      selfHeal: true           # revert out-of-band kubectl changes back to Git
    syncOptions:
      - CreateNamespace=true   # creates 'app' if it isn't there
```

> Our repo is **public**, so Argo CD reads it with no credentials. For a private repo you'd first
> register a credential (a GitHub token or deploy key) in Argo CD.

Apply it:

```bash
kubectl apply -f argocd/app-v1.yaml
```

Then inspect it (or just watch it appear in the Argo CD UI):

```bash
kubectl get application onlineboutique -n argocd
```

### What you'll see

The app appears in the UI as `onlineboutique` with the full boutique service tree. Because the
workloads already exist in the cluster, it shows **Healthy** immediately, and since our Application
enables automated sync, Argo CD reconciles on its own and it settles on **Synced / Healthy**.

> If you ever need to trigger a reconcile by hand, use the **Sync** button in the Argo CD UI.

### Sync policy: auto-sync, prune, self-heal

The Application above enables `automated` sync with `prune` and `selfHeal` directly in the manifest —
no extra command needed. What each does, and why we want it:

- **`automated`** — Argo CD applies any new commit automatically, so a push to `main` is all it
  takes to deploy.
- **`prune: true`** — deletes resources removed from Git, so the cluster never drifts from the repo.
- **`selfHeal: true`** — reverts manual `kubectl` edits back to Git (GitOps hygiene).

> **Keep the Application out of the synced path.** `argocd/app-v1.yaml` is intentionally *not* under
> `k8s-manifest/app`, so Argo CD doesn't try to manage its own Application object as a workload.

## Summary

```
Argo CD     → watches Git, reconciles the cluster   (source of truth = the repo)
Application → repoURL + path + destination namespace (onlineboutique → app)
Sync policy → automated + prune + selfHeal           (hands-off, GitOps-clean)
```

With GitOps in place, the cluster now reconciles itself from this repo — a push to `main` is all it
takes to deploy, and any drift is corrected automatically. That wraps the playbook.