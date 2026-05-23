# wmp-helm-v2

Helm chart for deploying **Wealth Management Platform (WMP)** microservices on Kubernetes (EKS). One chart, multiple **value files** — install each app (`frontend`, `auth-service`, `portfolio-service`, `analytics-service`) with its own `values/<component>.yml`.

Includes an optional **`aws-ssm/`** helper to seed **SSM Parameter Store** and a **`ssm-pull`** init-container image for runtime config (used by `analytics-service`).

## Architecture

```text
                    ┌─────────────────┐
                    │ Traefik Ingress │  (optional, frontend)
                    └────────┬────────┘
                             │
     ┌───────────────────────┼───────────────────────┐
     │                       │                       │
 frontend              auth-service          portfolio-service
 (ClusterIP/LB)         (ClusterIP)            (ClusterIP)
     │                       │                       │
     └───────────────────────┼───────────────────────┘
                             │
                    analytics-service
                    (init: ssm-pull → /data/params)
                             │
                    AWS SSM Parameter Store
                    /analytics-service/*
```

| Template | Purpose |
|----------|---------|
| `templates/deployment.yml` | Deployment, optional **ssm-pull** init container, app container from ECR |
| `templates/service.yml` | ClusterIP (or type from values) |
| `templates/serviceaccount.yml` | Per-app ServiceAccount (for EKS Pod Identity / IAM) |
| `templates/ingress.yml` | Traefik `Ingress` when `ingress.enabled: true` |

Default image pattern:

```text
739561048503.dkr.ecr.us-east-1.amazonaws.com/<appName>:<image_tag>
```

Set **`image_tag`** at install time (Git SHA, `latest`, etc.).

## Repository layout

```text
.
├── Chart.yaml
├── values.yaml              # defaults (replicas, ingress off)
├── values/
│   ├── frontend.yml
│   ├── auth-service.yml
│   ├── portfolio-service.yml
│   └── analytics-service.yml
├── templates/
├── Makefile                 # helm install wrapper
└── aws-ssm/                 # Terraform SSM params + ssm-pull Docker image
    ├── main.tf
    ├── Dockerfile
    ├── run.sh
    └── Makefile
```

## Prerequisites

- **kubectl** and **helm 3** configured for your cluster  
  `aws eks update-kubeconfig --name dev --region us-east-1`
- **Traefik** (or compatible ingress class **`traefik`**) if using ingress
- **ECR** images built and pushed for each service (`frontend`, `auth-service`, etc.)
- For **analytics-service** SSM flow:
  - SSM parameters under `/<service-name>/...` (see `aws-ssm/main.tf`)
  - **`ssm-pull`** image in ECR (`739561048503.dkr.ecr.us-east-1.amazonaws.com/ssm-pull:latest`)
  - **Pod Identity / IAM** on ServiceAccount `analytics-service` with `ssm:GetParameter*` (see EKS Terraform in `wmp-terraform-encrypt-n-network-v9`)
- Target **namespace** created (e.g. `wmp-eks-namespace` or `default`)

## Install with Helm (direct)

From the chart root:

```bash
# 1. Namespace (example)
kubectl create namespace wmp-eks-namespace --dry-run=client -o yaml | kubectl apply -f -

# 2. Install one component (set image_tag to your build)
helm upgrade --install frontend . \
  -n wmp-eks-namespace \
  -f values/frontend.yml \
  --set image_tag=latest

helm upgrade --install auth-service . \
  -n wmp-eks-namespace \
  -f values/auth-service.yml \
  --set image_tag=latest

helm upgrade --install portfolio-service . \
  -n wmp-eks-namespace \
  -f values/portfolio-service.yml \
  --set image_tag=latest

helm upgrade --install analytics-service . \
  -n wmp-eks-namespace \
  -f values/analytics-service.yml \
  --set image_tag=latest
```

Using the **Makefile** (install only, no namespace/image_tag flags — extend as needed):

```bash
make helm-install component=frontend
# requires: helm install $(component) . -f values/$(component).yml
# add --set image_tag=... and -n ... manually or extend Makefile
```

Recommended Makefile-style one-liner with tag and namespace:

```bash
export NS=wmp-eks-namespace
export TAG=abc1234   # git SHA or latest

helm upgrade --install frontend . -n $NS -f values/frontend.yml --set image_tag=$TAG
helm upgrade --install auth-service . -n $NS -f values/auth-service.yml --set image_tag=$TAG
helm upgrade --install portfolio-service . -n $NS -f values/portfolio-service.yml --set image_tag=$TAG
helm upgrade --install analytics-service . -n $NS -f values/analytics-service.yml --set image_tag=$TAG
```

### Verify

```bash
kubectl get pods,svc,ingress -n wmp-eks-namespace
helm list -n wmp-eks-namespace
```

### Uninstall

```bash
helm uninstall frontend -n wmp-eks-namespace
helm uninstall auth-service -n wmp-eks-namespace
helm uninstall portfolio-service -n wmp-eks-namespace
helm uninstall analytics-service -n wmp-eks-namespace
```

## Install with Argo CD

Point Argo CD at this repo (path `.`) and pass values file + `image_tag` via Helm parameters.

**CLI example** (after `argocd login`):

```bash
argocd app create frontend \
  --repo https://github.com/wmp-project/wmp-helm-v2.git \
  --path . \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace wmp-eks-namespace \
  --helm-set-string image_tag=abc1234 \
  --values values/frontend.yml \
  --sync-policy automated \
  --upsert
```

Repeat for `auth-service`, `portfolio-service`, `analytics-service` with the matching `values/<name>.yml`.

**UI:** New App → Git repo URL → path `.` → Helm → values file `values/frontend.yml` → parameter `image_tag`.

## Ingress (frontend)

In `values/frontend.yml`, `ingress.enabled: true` creates:

- **Host:** `frontend-dev.raghudevopsb88.online` (from template; adjust in `templates/ingress.yml` for your domain)
- **Class:** `traefik`

Ensure **ExternalDNS** / Route 53 (or manual DNS) points the hostname at your Traefik NLB.

Backend services (`auth-service`, `portfolio-service`, `analytics-service`) use **ClusterIP** only; the frontend nginx proxies to them inside the cluster.

## AWS SSM setup (analytics-service)

### 1. Create parameters (Terraform)

```bash
cd aws-ssm
make def
# or: terraform init && terraform apply -auto-approve
```

Creates parameters such as:

- `/analytics-service/DATABASE_URL`
- `/analytics-service/DB_SCHEMA`
- `/analytics-service/LOG_LEVEL`
- `/analytics-service/ENVIRONMENT`

### 2. Build and push `ssm-pull` init image

```bash
cd aws-ssm
make docker-build
```

### 3. Deploy analytics-service

The deployment init container reads `PARAMS` from values and writes exports to `/data/params` for the app container.

```bash
helm upgrade --install analytics-service . \
  -n wmp-eks-namespace \
  -f values/analytics-service.yml \
  --set image_tag=latest
```

## Values reference

| Key | Description |
|-----|-------------|
| `appName` | Deployment, Service, ServiceAccount name; ECR repo name |
| `appPort` | Service and container port |
| `serviceType` | `ClusterIP` or `LoadBalancer` |
| `replicas` | From `values.yaml` default (2) unless overridden |
| `image_tag` | **Required at install** — Docker image tag |
| `ingress.enabled` | Enable Traefik ingress |
| `PARAMS` | Space-separated SSM param names for init container (analytics) |
| `config_values` | Present in some value files; wire via ConfigMap/SSM as your templates evolve |

Update RDS hosts, secrets, and domains in `values/*.yml` for each environment before production use.

## Related repos

- Application images: `frontend`, `auth-service`, `portfolio-service`, `analytics-service`
- Raw K8s manifests (lab): `learn-kubernetes-eks/wmp-v1/05.yml`
- EKS / Traefik / Argo CD infra: `wmp-terraform-encrypt-n-network-v9`
- CI deploy (Makefile): service repos `make argocd-deploy`

## Notes

- **Lab defaults** in value files may contain plaintext DB passwords; prefer SSM/Secrets Manager for non-lab.
- Chart **`Chart.yaml`** `name` should be a single identifier (no spaces) for strict Helm tooling; rename locally if `helm lint` complains.
- ECR account **`739561048503`** and domains in ingress templates must match your AWS account and DNS.
