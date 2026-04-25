create or replace table `formelskin-492502.formel_data.1_stg_consultations`  as 

-- each row represents clinical or support interaction with a patient
-- it tracks every touchpoint the ops/clinical team has with a customer throughout their treatment journey.
with base as (
  select 
    consultation_id,
    customer_id,
    order_id,
    consultation_date as consultation_timestamp,
    date(consultation_date) as consultation_date,
    resolution_time as resolution_timestamp,
    date(resolution_time) as resolution_date,
    assignee,
    consultation_type,
    current_status,


  from `formelskin-492502.formel_data.consultations`
) 

select 
  *
from base 