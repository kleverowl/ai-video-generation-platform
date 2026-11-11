---
name: cost-estimate
description: Compute Cloud Run GPU/CPU job cost from verified unit rates and measured or parametric durations. Use for any question about GPU cost, cost per video, region price comparison, or GPU SKU break-even.
---

# Cost estimate

## Verified rates (Cloud Run jobs, instance-based; per second; verified 2026-11-11 during the architecture review)

| Item | Tier 1 (europe-west4, us-central1) | asia-southeast1 (×1.2) |
|---|---|---|
| L4 GPU | 0.0001867 | 0.00022404 |
| RTX PRO 6000 GPU | 0.00036522 | 0.00043826 |
| vCPU | 0.000018 | 0.0000216 |
| GiB RAM | 0.000002 | 0.0000024 |

**Hourly:**
- L4 8/32: $1.4209 (Tier 1), $1.7051 (Singapore)
- RTX PRO 6000 20/80: $3.1868 (Tier 1), $3.8241 (Singapore)

**Re-verify** at https://cloud.google.com/run/pricing if these rates are more than ~90 days old, and update this table.

## Formula (04 §15.2)

```
GPU $ = (gpu + vcpu*n_cpu + ram*gib) * (T_start + T_stage + N_clips*t_clip + T_te + T_vae + T_upload)
Egress $ ≈ 0.12 * final_GiB   (render job → R2)
```

## Rules
- Use **measured** durations from `docs/poc/` when they exist. Otherwise present the result as a formula or range and label it `ESTIMATE`.
- Always show the arithmetic.
- Break-even rule: the RTX PRO 6000 must be ≥ 2.24× faster per output-second than an L4 8/32 to be cheaper.
