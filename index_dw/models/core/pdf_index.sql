with dim_book as (
    select * from {{ ref('stg_dim_book')}}
),

dim_word as (
    select * from {{ ref('stg_dim_word')}}
),

index_fact as (
    select * from {{ ref('stg_index_fact')}}
)

select w.Word as Word,
    b.FileName as FileName,
    i.PageNumber as PageNumber
from index_fact i
left join dim_book b
on i.BookID = b.BookID
left join dim_word w
on i.WordID = w.WordID