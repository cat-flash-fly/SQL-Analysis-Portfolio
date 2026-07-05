# 创建表
DROP TABLE IF EXISTS chocolate_sales;
CREATE TABLE chocolate_sales (
    sales_person VARCHAR(100),
    country VARCHAR(50),
    product VARCHAR(100),
    sale_date DATE,
    amount DECIMAL(10, 2),
    boxes_shipped INT);

# 导入数据，并修改格式
LOAD DATA LOCAL INFILE '文件路径/Chocolate Sales.csv'
INTO TABLE chocolate_sales
FIELDS TERMINATED BY ',' 
OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(sales_person, country, product, @date_str, @amount_str, boxes_shipped)
SET 
    sale_date = STR_TO_DATE(@date_str, '%m/%d/%Y'),
    amount = CAST(REPLACE(REPLACE(@amount_str, '$', ''), ',', '') AS DECIMAL(10, 2));


# 数据清洗
# 1.检测重复订单
WITH det AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY sales_person, country, product, sale_date, amount 
               ORDER BY sale_date
           ) AS rk
    FROM chocolate_sales
)

SELECT COUNT(*) AS duplicate_count FROM det WHERE rk > 1;

# 2.检测空值
SELECT 
    SUM(CASE WHEN sales_person IS NULL THEN 1 ELSE 0 END) AS null_sales_person,
    SUM(CASE WHEN country IS NULL THEN 1 ELSE 0 END) AS null_country,
    SUM(CASE WHEN product IS NULL THEN 1 ELSE 0 END) AS null_product,
    SUM(CASE WHEN sale_date IS NULL THEN 1 ELSE 0 END) AS null_date,
    SUM(CASE WHEN amount IS NULL THEN 1 ELSE 0 END) AS null_amount,
    SUM(CASE WHEN boxes_shipped IS NULL THEN 1 ELSE 0 END) AS null_boxes
FROM chocolate_sales;

# 3.按年份的销售额、销售数量、客单价
SELECT 
    YEAR(sale_date) AS year,
    ROUND(SUM(amount), 2) AS total_sales,
    SUM(boxes_shipped) AS total_boxes,
    ROUND(SUM(amount) / NULLIF(SUM(boxes_shipped), 0), 2) AS avg_price_per_box,
FROM chocolate_sales
GROUP BY YEAR(sale_date)
ORDER BY year;


# 按年份+国家的销售额、数量、客单价及环比
WITH country_yearly AS (
    SELECT 
        YEAR(sale_date) AS year,
        country,
        ROUND(SUM(amount), 2) AS total_sales,
        SUM(boxes_shipped) AS total_boxes,
        ROUND(SUM(amount) / NULLIF(SUM(boxes_shipped), 0), 2) AS avg_price_per_box
    FROM chocolate_sales
    GROUP BY YEAR(sale_date), country
),
country_with_lag AS (
    SELECT 
        year,
        country,
        total_sales,
        total_boxes,
        avg_price_per_box,
        LAG(total_sales, 1) OVER (PARTITION BY country ORDER BY year) AS prev_year_sales,
        LAG(total_boxes, 1) OVER (PARTITION BY country ORDER BY year) AS prev_year_boxes,
        LAG(avg_price_per_box, 1) OVER (PARTITION BY country ORDER BY year) AS prev_year_avg_price
    FROM country_yearly
)
SELECT 
    year,
    country,
    total_sales,
    total_boxes,
    avg_price_per_box,
    ROUND((total_sales - prev_year_sales) / NULLIF(prev_year_sales, 0) * 100, 2) AS sales_growth_pct,
    ROUND((total_boxes - prev_year_boxes) / NULLIF(prev_year_boxes, 0) * 100, 2) AS boxes_growth_pct,
    ROUND((avg_price_per_box - prev_year_avg_price) / NULLIF(prev_year_avg_price, 0) * 100, 2) AS price_growth_pct
FROM country_with_lag
ORDER BY country, year;

# 按年份和产品的销售额、数量、客单价及环比
WITH product_yearly AS (
    SELECT 
        YEAR(sale_date) AS year,
        product,
        ROUND(SUM(amount), 2) AS total_sales,
        SUM(boxes_shipped) AS total_boxes,
        ROUND(SUM(amount) / NULLIF(SUM(boxes_shipped), 0), 2) AS avg_price_per_box
    FROM chocolate_sales
    GROUP BY YEAR(sale_date), product
),
product_with_lag AS (
    SELECT 
        year,
        product,
        total_sales,
        total_boxes,
        avg_price_per_box,
        LAG(total_sales, 1) OVER (PARTITION BY product ORDER BY year) AS prev_year_sales,
        LAG(total_boxes, 1) OVER (PARTITION BY product ORDER BY year) AS prev_year_boxes,
        LAG(avg_price_per_box, 1) OVER (PARTITION BY product ORDER BY year) AS prev_year_avg_price
    FROM product_yearly
)
SELECT 
    year,
    product,
    total_sales,
    total_boxes,
    avg_price_per_box,
    ROUND((total_sales - prev_year_sales) / NULLIF(prev_year_sales, 0) * 100, 2) AS sales_growth_pct,
    ROUND((total_boxes - prev_year_boxes) / NULLIF(prev_year_boxes, 0) * 100, 2) AS boxes_growth_pct,
    ROUND((avg_price_per_box - prev_year_avg_price) / NULLIF(prev_year_avg_price, 0) * 100, 2) AS price_growth_pct
FROM product_with_lag
ORDER BY product, year;

# 按月份的销售额成交趋势
SELECT 
    DATE_FORMAT(sale_date, '%Y-%m') AS month,
    YEAR(sale_date) AS year,
    MONTH(sale_date) AS month_num,
    ROUND(SUM(amount), 2) AS monthly_sales,
    SUM(boxes_shipped) AS monthly_boxes,
    COUNT(*) AS order_count,
    ROUND(SUM(amount) / NULLIF(SUM(boxes_shipped), 0), 2) AS avg_price_per_box,
    ROUND(
        (SUM(amount) - LAG(SUM(amount), 1) OVER (ORDER BY DATE_FORMAT(sale_date, '%Y-%m'))) 
        / NULLIF(LAG(SUM(amount), 1) OVER (ORDER BY DATE_FORMAT(sale_date, '%Y-%m')), 0) * 100, 
        2
    ) AS sales_mom_growth_pct
FROM chocolate_sales
GROUP BY DATE_FORMAT(sale_date, '%Y-%m'), YEAR(sale_date), MONTH(sale_date)
ORDER BY YEAR(sale_date), MONTH(sale_date);


