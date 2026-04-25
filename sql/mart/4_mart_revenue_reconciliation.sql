create or replace table `formelskin-492502.formel_data.4_mart_revenue_reconciliation` as

with orders as (
    select *
    from `formelskin-492502.formel_data.2_int_orders`
    where is_recognized_revenue
),

full_joined_data as (
    select
        coalesce(ord.order_id, inv.order_id)                     as order_id,
        coalesce(ord.order_revenue_month, inv.invoice_revenue_month) as revenue_month,

        -- ORDER SIDE
        ord.customer_id,
        ord.product_name,
        ord.order_date,
        ord.order_paid_date,
        ord.user_country,
        ord.order_currency,
        ord.order_amount_eur,
        ord.order_refund_amount_eur,
        ord.order_net_revenue_eur,
        ord.order_revenue_month,
        ord.order_status,

        -- INVOICE SIDE
        inv.invoice_id,
        inv.invoice_date,
        inv.invoice_currency,
        inv.invoice_gross_amount_eur,
        inv.invoice_refund_amount_eur,
        inv.invoice_net_revenue_eur,
        inv.invoice_revenue_month,
        inv.total_invoice_events

    from orders ord
    full join `formelskin-492502.formel_data.2_int_invoices_aggregated` inv
        on ord.order_id = inv.order_id
),

final as (
    select
        order_id,
        revenue_month,

        -- ORDER SIDE
        customer_id,
        product_name,
        order_date,
        order_paid_date,
        user_country,
        order_currency,
        order_amount_eur,
        order_refund_amount_eur,
        order_net_revenue_eur,
        order_status,

        -- INVOICE SIDE
        invoice_id,
        invoice_date,
        invoice_currency,
        invoice_gross_amount_eur,
        invoice_refund_amount_eur,
        invoice_net_revenue_eur,
        total_invoice_events,

        -- METRICS
        coalesce(order_net_revenue_eur, 0) - coalesce(invoice_net_revenue_eur, 0) as revenue_diff_eur,
        date_diff(invoice_date, order_date, day)                           as invoice_lag_days,

        -- DISCREPANCY CLASSIFICATION
        case
            when order_net_revenue_eur is null and invoice_net_revenue_eur > 0
                then '1. invoice_without_order'
            when order_net_revenue_eur is null and invoice_net_revenue_eur < 0
                then '2. refund_without_order'
            when order_net_revenue_eur is not null and invoice_net_revenue_eur is null
                then '3. missing_invoice'
            when coalesce(order_net_revenue_eur, 0) != coalesce(invoice_net_revenue_eur, 0)
                and invoice_currency != order_currency
                then '4. currency_and_revenue_mismatch'
            when coalesce(order_net_revenue_eur, 0) != coalesce(invoice_net_revenue_eur, 0)
                and coalesce(order_refund_amount_eur, 0) != coalesce(invoice_refund_amount_eur, 0)
                then '5. revenue_mismatch_refund'
            when coalesce(order_net_revenue_eur, 0) = coalesce(invoice_net_revenue_eur, 0)
                then '6. no_mismatch'
            else '7. revenue_mismatch'
        end as discrepancy_type,

        -- FLAGS
        case
            when coalesce(order_net_revenue_eur, 0) = coalesce(invoice_net_revenue_eur, 0)
                and invoice_net_revenue_eur is not null
                then true
            else false
        end as is_reconciled,

        total_invoice_events > 1 as has_multiple_invoice_events,

    from full_joined_data
)

select 
  *,
  -- INVOICE LAG BUCKET
  case
      when invoice_lag_days is null      then 'a. not_invoiced'
      when invoice_lag_days <= 30        then 'b. 0-30 days'
      when invoice_lag_days <= 60        then 'c. 31-60 days'
      when invoice_lag_days <= 90        then 'd. 61-90 days'
      else                                    'e. 90+ days'
  end as invoice_lag_bucket,
  abs(revenue_diff_eur) as absolute_revenue_diff_eur
from final