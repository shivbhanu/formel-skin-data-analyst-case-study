create or replace table `formelskin-492502.formel_data.2_int_orders`  as 

with base as (
  select 
    order_id, 
    customer_id,
    product_name,
    order_timestamp,
    order_date,
    order_paid_timestamp,
    order_paid_date,
    user_country,
    order_currency,
    order_amount,
    if(order_currency = 'CHF', order_amount*1.09, order_amount) as order_amount_eur,
    order_refund_amount,
    if(order_currency = 'CHF', order_refund_amount*1.09, order_refund_amount) as order_refund_amount_eur,
    order_status,
    -- order_amount - order_refund_amount as order_revenue,
    coalesce(order_paid_date, order_date) as order_revenue_date, -- ideally to only use order_paid_date but keeping it here just in case required during demonstration of case study
    date_trunc(coalesce(order_paid_date, order_date), month) as order_revenue_month,
    order_paid_date is not null as is_recognized_revenue,   -- any order which has payment date associated to it is considered paid and is counted towards revenue (why? -> the dataset provided has most of the orders paid in Jan 2026)
    date_diff(order_paid_date, order_date, day) as days_to_payment,

  from `formelskin-492502.formel_data.1_stg_orders` 
) 

select 
  *,
  order_amount - order_refund_amount as order_net_revenue,
  order_amount_eur - order_refund_amount_eur as order_net_revenue_eur,
  CASE 
      WHEN days_to_payment < 0 THEN 'a. Invalid'
      WHEN days_to_payment <= 30 THEN 'b. 0-30 days'
      WHEN days_to_payment <= 60 THEN 'c. 31-60 days'
      WHEN days_to_payment <= 90 THEN 'd. 61-90 days'
      when days_to_payment is null then 'e. Unpaid'
      ELSE 'f. 90+ days'
  END AS days_to_payment_bucket   -- https://docs.google.com/spreadsheets/d/1eKeCJZ27UzCJCfqbPBr1dVmPrH4YhIsk_mKeQekkbDc/edit?gid=1391184333#gid=1391184333
from base 