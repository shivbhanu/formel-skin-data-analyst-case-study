CREATE OR REPLACE TABLE `formelskin-492502.formel_data.4_mart_ops_kpis` AS

-- ┌─────────────────────────────────────────────────────────────────────────┐
-- │ KPI FORMULAS (all aggregated in BI tool on top of atomic rows)          │
-- │                                                                         │
-- │ DOMAIN 1 · ORDER FULFILLMENT                                            │
-- │ Measures whether the business is collecting revenue effectively.        │
-- │ Query via 2_int_orders explore in Looker to avoid fan-out from the      │
-- │ one-to-many orders → consultations relationship.                        │
-- │                                                                         │
-- │ KPI 1 · Order completion rate                                           │
-- │   COUNTIF(order_status = 'paid') / COUNT(order_id)                      │
-- │                                                                         │
-- │ KPI 2 · Partial payment rate                                            │
-- │   COUNTIF(order_status = 'partially_paid') / COUNT(order_id)            │
-- │                                                                         │
-- │ KPI 3 · Payment collection lag                                          │
-- │   PERCENTILE(days_to_payment, 0.5) → median                             │
-- │   PERCENTILE(days_to_payment, 0.9) → P90                                │
-- │   Note: NULLs excluded automatically (unpaid orders have no paid_date)  │
-- │                                                                         │
-- │ DOMAIN 2 · CONSULTATION OPERATIONS                                      │
-- │ Measures how effectively the ops/clinical team resolves consultations.  │
-- │ Aggregated on consultation grain — no fan-out risk.                     │
-- │                                                                         │
-- │ KPI 4 · Consultation resolution rate                                    │
-- │   COUNTIF(is_resolved = true) / COUNT(consultation_id)                  │
-- │                                                                         │
-- │ KPI 5 · Resolution time SLA                                             │
-- │   PERCENTILE(calendar_resolution_hours, 0.5) WHERE is_resolved = true   │
-- │   PERCENTILE(calendar_resolution_hours, 0.9) WHERE is_resolved = true   │
-- │   SLA breach rate:                                                      │
-- │   COUNTIF(is_sla_breached = true) / COUNTIF(is_resolved = true)         │
-- │                                                                         │
-- │ KPI 6 · Stuck queue rate                                                │
-- │   COUNTIF(is_stuck = true) / COUNT(consultation_id)                     │
-- │   Payment blocked:  COUNTIF(status_category = 'open_payment_blocked')   │
-- │   Waiting customer: COUNTIF(status_category = 'open_waiting_customer')  │
-- │                                                                         │
-- │ DOMAIN 3 · FULFILLMENT QUALITY                                          │
-- │ Measures whether the end-to-end process is working cleanly.             │
-- │ High repeat contact or refund rates signal upstream process failures.   │
-- │                                                                         │
-- │ KPI 7 · Repeat contact rate                                             │
-- │   COUNTIF(is_repeat_contact_order = true) / COUNT(consultation_id)      │
-- │   WHERE has_linked_order = true                                         │
-- │   Note: is_repeat_contact_order = true when order_consultation_count>=3 │
-- │                                                                         │
-- │ DOMAIN 4 · TEAM CAPACITY & EFFICIENCY                                   │
-- │ Measures individual assignee load and performance. Used to identify     │
-- │ overloaded agents and resolution time variance across the team.         │
-- │ Queried via 4_mart_assignee_load (separate table — assignee grain).     │
-- │                                                                         │
-- │ KPI 8 · Assignee load                                                   │
-- │   Total load:       COUNT(consultation_id) per assignee                 │
-- │   Resolution rate:  COUNTIF(is_resolved) / COUNT(consultation_id)       │
-- │   Stuck rate:       COUNTIF(is_stuck) / COUNT(consultation_id)          │
-- │   Resolution time:  PERCENTILE(calendar_resolution_hours, 0.5)          │
-- │                     WHERE is_resolved = true, per assignee              │
-- └─────────────────────────────────────────────────────────────────────────┘

with consultations_per_order as (
  SELECT
    order_id,
    COUNT(consultation_id)                                AS consultation_count,
  FROM `formelskin-492502.formel_data.2_int_consultations`
  WHERE order_id IS NOT NULL
  GROUP BY order_id
)

SELECT
  -- ── Consultation dimensions ───────────────────────────────────────────
  c.consultation_id,
  c.customer_id,
  c.consultation_timestamp,
  c.consultation_date,
  c.consultation_month,
  c.assignee,
  c.consultation_type,
  c.lifecycle_stage,
  c.resolution_timestamp,
  c.resolution_date,
  c.current_status,
  c.status_category,

  -- ── DOMAIN 2 · Consultation measures (boolean flags for BI aggregation)
  -- KPI 4: numerator = COUNTIF(is_resolved), denominator = COUNT(consultation_id)
  c.is_resolved,
  -- KPI 6: numerator = COUNTIF(is_stuck), denominator = COUNT(consultation_id)
  c.is_stuck,
  c.is_closed_unresolved,
  -- KPI 5: used as filter — only aggregate calendar_resolution_hours where is_sla_breached
  c.is_sla_breached,
  c.has_linked_order,
  -- KPI 5: PERCENTILE(calendar_resolution_hours, 0.5 / 0.9) WHERE is_resolved = true
  c.calendar_resolution_hours,
  c.sla_bucket,

  -- ── DOMAIN 3 · Repeat contact flag (pre-computed at order level) ───────
  -- KPI 7: numerator = COUNTIF(is_repeat_contact_order) WHERE has_linked_order = true
  --        denominator = COUNT(consultation_id) WHERE has_linked_order = true
  rc.consultation_count                                   AS order_consultation_count,
  rc.consultation_count >= 3                              AS is_repeat_contact_order,

  -- ── DOMAIN 1 · Order dimensions (NULL where no linked order) ───────────
  o.order_id,
  o.product_name,
  o.order_status,
  o.order_date,
  o.order_revenue_date,
  o.order_revenue_month,
  -- KPI 3: PERCENTILE(days_to_payment, 0.5 / 0.9) — query via 2_int_orders explore
  o.days_to_payment,
  o.days_to_payment_bucket,
  o.is_recognized_revenue,

  -- ── DOMAIN 1 · Order measures ─────────────────────────────────────────
  -- KPI 1/2: query SUM/COUNT via 2_int_orders explore to avoid fan-out
  o.order_amount_eur,
  o.order_net_revenue_eur,
  o.order_refund_amount_eur,

FROM `formelskin-492502.formel_data.2_int_consultations`     c

LEFT JOIN `formelskin-492502.formel_data.2_int_orders`       o
       ON c.order_id = o.order_id

LEFT JOIN consultations_per_order      rc
       ON c.order_id = rc.order_id