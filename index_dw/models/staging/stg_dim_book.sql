{{ config(materialized='view') }}

select BookID as BookID
    , RIGHT(FileName, LENGTH(FileName) - 4) as FileName
from {{ source('staging', 'dim_book')}}