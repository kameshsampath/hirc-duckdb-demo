--!jinja
-- Create a sample Iceberg table with test data
-- Run via Snowflake (DuckDB can't write to Iceberg tables through Horizon Catalog)
--
-- Usage:
--   snow sql -f 03.sample_data.sql \
--     --enable-templating ALL \
--     --variable database_name=$DEMO_DATABASE \
--     --variable external_volume_name=$EXTERNAL_VOLUME_NAME

USE DATABASE {{database_name}};
USE SCHEMA PUBLIC;

-- Create a simple Iceberg table
CREATE OR REPLACE ICEBERG TABLE fruits (
    id INT,
    name VARCHAR(100),
    color VARCHAR(50),
    price DECIMAL(10,2),
    in_stock BOOLEAN
)
    CATALOG = 'SNOWFLAKE'
    EXTERNAL_VOLUME = '{{external_volume_name}}'
    BASE_LOCATION = 'fruits/';

-- Insert sample data
INSERT INTO fruits (id, name, color, price, in_stock)
VALUES
    (1, 'Apple', 'Red', 1.50, TRUE),
    (2, 'Banana', 'Yellow', 0.75, TRUE),
    (3, 'Orange', 'Orange', 2.00, TRUE),
    (4, 'Grape', 'Purple', 3.50, TRUE),
    (5, 'Mango', 'Yellow', 2.50, FALSE),
    (6, 'Strawberry', 'Red', 4.00, TRUE),
    (7, 'Blueberry', 'Blue', 5.00, TRUE),
    (8, 'Kiwi', 'Green', 1.75, FALSE),
    (9, 'Pineapple', 'Yellow', 3.00, TRUE),
    (10, 'Watermelon', 'Green', 6.00, TRUE);

-- Verify the data
SELECT * FROM fruits;

