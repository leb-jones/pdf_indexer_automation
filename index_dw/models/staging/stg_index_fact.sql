{{ config(materialized='view') }}

select * from {{ source('staging', 'index_fact')}}