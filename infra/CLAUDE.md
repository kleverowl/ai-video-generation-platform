# Infra rules

- **Planning only.** Claude never runs `terraform apply`, `gcloud … deploy/create`, or any other resource-creating command unless the user explicitly asks in that session. `plan` and `validate` are fine.
- **Region: `us-central1`** (ADR-0003). Fallback: `europe-west4`. Never default to Singapore.
- **One region per environment.** Model bucket, work bucket, Artifact Registry and all jobs live in the same region.
- **Isolation:** each environment (dev, prod) gets its own GCP project. Prod has a **budget spend cap**.
- **Do not add without an ADR:** VPC connectors, Cloud NAT, Direct VPC, min-instances, or always-on VMs. These cost money while idle or slow down cold starts.
- **State:** Terraform state goes in a remote backend. `*.tfvars` holding real values are git-ignored. Commit `*.tfvars.example` instead.
- **Oracle VM:**
  - SSH by key only.
  - Postgres listens on localhost only.
  - Only ports 80 and 443 are open, and only to Cloudflare IP ranges.
  - WAL-G or pgBackRest archives to R2.
