CREATE OR REPLACE TABLE `formelskin-492502.formel_data.2_int_consultations` AS

WITH base AS (
  SELECT
    consultation_id,
    customer_id,
    order_id,
    consultation_timestamp,
    consultation_date,
    DATE_TRUNC(consultation_date, MONTH)                AS consultation_month,
    resolution_timestamp,
    resolution_date,
    assignee,
    consultation_type,
    current_status,
    order_id IS NOT NULL                                AS has_linked_order,

    -- Status classification
    CASE
      WHEN current_status = 'done'
        THEN 'terminal_success'
      WHEN current_status IN ('canceled', 'rejected')
        THEN 'terminal_failure'
      WHEN current_status IN (
        'paymentPending', 'repurchasepaymentpending', 'registrationpending'
      )
        THEN 'open_payment_blocked'
      WHEN current_status IN ('waitingfileupload', 'waitingCustomerResponse')
        THEN 'open_waiting_customer'
      WHEN current_status = 'created'
        THEN 'open_active'
      ELSE 'unknown'
    END                                                 AS status_category,

    -- Boolean flags
    current_status = 'done'                             AS is_resolved,
    current_status IN ('canceled', 'rejected')          AS is_closed_unresolved,
    current_status IN (
      'paymentPending', 'repurchasepaymentpending',
      'registrationpending', 'waitingfileupload',
      'waitingCustomerResponse', 'created'
    )                                                   AS is_stuck,

    -- Lifecycle stage
    CASE consultation_type
      WHEN 'initial'        THEN '1_acquisition'
      WHEN 'imageUpload'    THEN '2_intake'
      WHEN 'checkin'        THEN '3_treatment'
      WHEN 'mid2mUpdate'    THEN '3_treatment'
      WHEN 'askYourDoctor'  THEN '3_treatment'
      WHEN 'renewal'        THEN '4_renewal'
      WHEN 'repurchase'     THEN '5_repurchase'
      WHEN 'inquiry'        THEN '6_support'
      ELSE                       '7_other'
    END                                                 AS lifecycle_stage,

    -- Calendar resolution hours
    -- Assumption: calendar hours used for simplicity.
    -- Business hours (Mon–Fri 09–18 CET) would reduce P90 from ~134h to ~33h.
    -- Only meaningful for terminal statuses — NULL otherwise.
    ROUND(
      TIMESTAMP_DIFF(resolution_timestamp, consultation_timestamp, SECOND) / 3600.0
    , 2)                                                AS calendar_resolution_hours,

  FROM `formelskin-492502.formel_data.1_stg_consultations`
)

SELECT
  *,

  -- SLA bucket (calendar hours, resolved consultations only)
  -- Assumption: P90 target = 72 calendar hours (3 calendar days).
  -- To be revisited with business hours post-interview.
  CASE
    WHEN NOT is_resolved                                THEN NULL
    WHEN calendar_resolution_hours <= 24                THEN 'a. same_day'
    WHEN calendar_resolution_hours <= 72                THEN 'b. within_3d'
    WHEN calendar_resolution_hours <= 168               THEN 'c. within_week'
    ELSE                                                     'd. over_week'
  END                                                   AS sla_bucket,

  calendar_resolution_hours > 72
    AND is_resolved                                     AS is_sla_breached,

FROM base