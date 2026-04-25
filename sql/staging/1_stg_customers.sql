create or replace table `formelskin-492502.formel_data.1_stg_customers`  as 

select 
  distinct 
  customer_id,
  user_country

from `formelskin-492502.formel_data.orders` 