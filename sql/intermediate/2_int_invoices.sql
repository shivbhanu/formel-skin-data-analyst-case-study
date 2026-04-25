create or replace table `formelskin-492502.formel_data.2_int_invoices`  as 

with base as (
  select 
    invoice_sk,
    invoice_id,
    order_id,
    invoice_date,
    invoice_refund_date,
    invoice_gross_amount,
    if(invoice_currency = 'CHF', invoice_gross_amount*1.09, invoice_gross_amount) as invoice_gross_amount_eur,
    invoice_currency,
    invoice_refund_amount,
    if(invoice_currency = 'CHF', invoice_refund_amount*1.09, invoice_refund_amount) as invoice_refund_amount_eur,
    invoice_status,
    invoice_type,
    coalesce(invoice_refund_date, invoice_date) as invoice_revenue_date,
    date_trunc(coalesce(invoice_refund_date, invoice_date), month) as invoice_revenue_month,
    -- invoice_gross_amount - invoice_refund_amount as invoice_revenue
    
  from `formelskin-492502.formel_data.1_stg_invoices`
) 

select 
  *,
  invoice_gross_amount - invoice_refund_amount as invoice_net_revenue,
  invoice_gross_amount_eur - invoice_refund_amount_eur as invoice_net_revenue_eur
from base 