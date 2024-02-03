-- 1) Creating the view "sales_revenue_by_category_qtr"
CREATE OR REPLACE VIEW sales_revenue_by_category_qtr AS
SELECT
    c.name AS category,
    COALESCE(SUM(p.amount), 0::numeric) AS total_sales_revenue
FROM
    category c
    JOIN film_category fc ON c.category_id = fc.category_id
    JOIN film f ON fc.film_id = f.film_id
    LEFT JOIN inventory i ON f.film_id = i.film_id
    LEFT JOIN rental r ON i.inventory_id = r.inventory_id
    LEFT JOIN payment p ON r.rental_id = p.rental_id
WHERE
    EXTRACT(year FROM CURRENT_DATE) = EXTRACT(year FROM p.payment_date)
    AND EXTRACT(quarter FROM CURRENT_DATE) = EXTRACT(quarter FROM p.payment_date)
GROUP BY
    c.name
ORDER BY
    total_sales_revenue ASC;

-- 2) Creating the function "get_sales_revenue_by_category_qtr"
CREATE OR REPLACE FUNCTION get_sales_revenue_by_category_qtr(current_quarter DATE)
RETURNS TABLE (category TEXT, total_sales_revenue NUMERIC)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.name AS category,
        COALESCE(SUM(p.amount), 0::numeric) AS total_sales_revenue
    FROM
        category c
        JOIN film_category fc ON c.category_id = fc.category_id
        JOIN film f ON fc.film_id = f.film_id
        LEFT JOIN inventory i ON f.film_id = i.film_id
        LEFT JOIN rental r ON i.inventory_id = r.inventory_id
        LEFT JOIN payment p ON r.rental_id = p.rental_id
    WHERE
        EXTRACT(year FROM current_quarter) = EXTRACT(year FROM p.payment_date)
        AND EXTRACT(quarter FROM current_quarter) = EXTRACT(quarter FROM p.payment_date)
    GROUP BY
        c.name
    ORDER BY
        total_sales_revenue ASC;
END;
$$;

-- 3) Creating the procedural function "new_movie"
CREATE OR REPLACE PROCEDURE new_movie(movie_title VARCHAR DEFAULT 'Rambo')
LANGUAGE plpgsql
AS $$
DECLARE
    s_language_id INT;
    new_film_id INT;
BEGIN
    -- Searching for the ID of the Klingon language
    SELECT language_id INTO s_language_id
    FROM language
    WHERE name = 'Klingon';

    -- Checking the existence of the language
    IF s_language_id IS NULL THEN
        RAISE EXCEPTION 'Language "Klingon" does not exist in the language table.';
    END IF;

    -- Generating a unique film_id
    SELECT COALESCE(MAX(film_id), 0) + 1 INTO new_film_id
    FROM film;

    -- Inserting a new movie
    INSERT INTO film (film_id, title, rental_rate, rental_duration, replacement_cost, release_year, language_id)
    VALUES (new_film_id, movie_title, 4.99, 3, 19.99, EXTRACT(YEAR FROM CURRENT_DATE), s_language_id);
END;
$$;





