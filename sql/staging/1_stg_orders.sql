create or replace table `formelskin-492502.formel_data.1_stg_orders`  as 

select 
  order_id, 
  customer_id,
  product_name,
  order_date as order_timestamp,
  date(order_date) as order_date,
  order_paid_date as order_paid_timestamp,
  date(order_paid_date) as order_paid_date,
  user_country,
  order_currency,
  order_amount,
  refund_amount as order_refund_amount,
  order_status,

from `formelskin-492502.formel_data.orders` 