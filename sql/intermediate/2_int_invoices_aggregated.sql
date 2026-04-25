create or replace table `formelskin-492502.formel_data.2_int_invoices_aggregated`  as 

select 
  order_id,
  invoice_date,
  invoice_currency,
  max(invoice_id) as invoice_id, -- taking the associated invoice id for the order id (for refunds there is no invoice_id)
  max(invoice_refund_date) as invoice_refund_date, --taking the latest refund date for the invoice
  max(invoice_revenue_date) as invoice_revenue_date, 
  max(invoice_revenue_month) as invoice_revenue_month,
  sum(invoice_gross_amount) as invoice_gross_amount,
  sum(invoice_refund_amount) as invoice_refund_amount,
  -- sum(coalesce(invoice_gross_amount,0) - coalesce(invoice_refund_amount, 0)) as invoice_revenue,
  sum(invoice_net_revenue) as invoice_net_revenue,
  sum(invoice_gross_amount_eur) as invoice_gross_amount_eur,
  sum(invoice_refund_amount_eur) as invoice_refund_amount_eur,
  -- sum(coalesce(invoice_gross_amount_eur,0) - coalesce(invoice_refund_amount_eur, 0)) as invoice_revenue_eur,
  sum(invoice_net_revenue_eur) as invoice_net_revenue_eur,
  count(*) as total_invoice_events  -- total events associated with an order_id in the invoice system
  
from `formelskin-492502.formel_data.2_int_invoices`
group by 1,2,3