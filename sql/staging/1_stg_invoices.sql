create or replace table `formelskin-492502.formel_data.1_stg_invoices`  as 

with base as (
  select 
    invoice_id,
    order_id,
    invoice_date,
    refund_date as invoice_refund_date,
    total_invoice_gross as invoice_gross_amount,
    invoice_currency,
    refund_amount as invoice_refund_amount,
    invoice_status,
    case 
      when total_invoice_gross > 0 then 'Revenue Invoice'
      when refund_amount > 0 then 'Refund Invoice'
      else 'Others'
    end as invoice_type

  from `formelskin-492502.formel_data.invoices`
) 

select 
  concat(order_id, coalesce(invoice_id, invoice_status), invoice_refund_amount) as invoice_sk,
  *
from base 