WITH fact AS (
    SELECT 
        f.WordID,
        w.Word,
        f.BookID,
        b.Book,
        f.PageNumber
    FROM {{ ref('index_fact') }} f
    LEFT JOIN {{ ref('dim_word') }} w ON f.WordID = w.WordID
    LEFT JOIN {{ ref('dim_book') }} b ON f.BookID = b.BookID
)

SELECT * FROM fact