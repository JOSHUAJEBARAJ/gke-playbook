# Day 1 — Observability

Welcome to Day 1 of the GKE Playbook. Today's goal is to build the monitoring and alerting system for the cluster.

We follow an SLO-first approach: define what "healthy" means for the user, then alert on it. This keeps alerts tied to real user impact instead of arbitrary thresholds.


## Stack

- **Collection**: Managed Prometheus (already enabled).
- **SLOs + alerting**: Cloud Monitoring, defined in Terraform (`google_monitoring_slo`, `google_monitoring_alert_policy`). Cloud Monitoring has native SLO and burn-rate primitives that map directly to the plan below.
- **Dashboards**: Grafana, pointed at Managed Prometheus / Cloud Monitoring.

## SLO

Both SLOs are measured over a **rolling 28-day window**, which defines the error budget.

- **Availability**: 99.9% of frontend requests should succeed (succeed = non-5xx; 4xx is the client's fault and counts as good).
  - Source: `frontend_5xx` (bad) over `frontend_latency` count (total).
  - Error budget: ~43 min of failures / 28 days.
- **Latency**: 99.5% of frontend requests should complete within 1 second.
  - Source: proportion of `frontend_latency` samples ≤ 1000 ms over total.
  - Error budget: ~3.4 h of slow requests / 28 days.



## Design

Each frontend request is logged to Cloud Logging. From those logs we extract log-based metrics for request latency and 5xx responses, and build the SLOs on top of them.


### Metrics

Three log-based metrics are defined in `logging.tf`:

- `frontend_latency` — a **DISTRIBUTION** metric of request latency (ms). Feeds the latency SLO via a distribution cut.
- `frontend_5xx` — a **DELTA INT64 counter** of 5xx responses (the "bad" numerator for availability).
- `frontend_requests` — a **DELTA INT64 counter** of all frontend requests (the "total" denominator for availability).

> Why a separate `frontend_requests` counter? Cloud Monitoring's `good_total_ratio` requires the
> `total` filter to point at a numeric metric. `frontend_latency` is a DISTRIBUTION, which it
> rejects, so we count total requests with a dedicated counter instead.

### SLOs

Defined in `slo.tf` as a custom service plus two SLOs (rolling 28-day window):

- `google_monitoring_custom_service.frontend` — the service the SLOs attach to.
- `google_monitoring_slo.availability` — `good_total_ratio`, bad = `frontend_5xx`, total = `frontend_requests`, goal 0.999.
- `google_monitoring_slo.latency` — `distribution_cut` on `frontend_latency`, good = samples ≤ 1000 ms, goal 0.995.

All metric filters are pinned to `resource.type="k8s_container"` so each resolves to a single resource type.

## Alerting

Defined in `alert.tf`. Each SLO gets two burn-rate alert policies (Google's multi-window,
multi-burn-rate pattern), all routed to an email notification channel
(`google_monitoring_notification_channel.email`, address from the `alert_email` variable):

- **Fast burn** — burn rate > 14.4× over a 1h window → page (acute outage).
- **Slow burn** — burn rate > 6× over a 6h window → warn (sustained degradation).

That's four policies total (`availability_fast_burn`, `availability_slow_burn`,
`latency_fast_burn`, `latency_slow_burn`).

> Note: the SLOs and the new `frontend_requests` metric only start producing data once the
> frontend receives traffic, so the budgets/alerts need a little live traffic before they read
> meaningfully.


## Dashboards

Grafana is deployed (see [Day 2 — Secret Management](day-2.md#secret-management) for how it's set up and accessed). Building the SLO and golden-signal dashboards on top of the Cloud Monitoring datasource is planned for a later day.
