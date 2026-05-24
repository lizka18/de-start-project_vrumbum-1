/*
Создание таблицы с сырыми данными

CREATE SCHEMA IF NOT EXISTS raw_data;
CREATE TABLE IF NOT exists raw_data.sales (
id INTEGER,
auto TEXT,
gasoline_consumption NUMERIC(3, 1),
price NUMERIC(9, 2),
date TIMESTAMP,
person TEXT,
phone TEXT,
discount INTEGER,
brand_origin TEXT
);

/*Комана для заполнения таблицы sales сырыми данными*/
/* \copy raw_data.sales(id, auto, gasoline_consumption, price, date, person, phone, discount, brand_origin) FROM 'C:\temp\cars.csv' NULL AS 'null' CSV HEADER;*/

*/

-- Этап 1. Создание и заполнение БД

CREATE SCHEMA IF NOT EXISTS car_shop;

CREATE TABLE IF NOT EXISTS car_shop.clients(
    customer_id SERIAL PRIMARY KEY,  /*Первичный ключ, автоинкремент по условию задания*/
    full_name TEXT NOT NULL, /*ФИО клиента записывается буквами, длинна заранее не известна, поэтому длину не ограничиваем*/
    phone TEXT NOT NULL UNIQUE /*номер телефона содержит цифры и символы (+, ), -), поэтому используем символьный тип данных. У номера нет единого формата, т.к. представлены номера разных стран, 
							поэтому не стала ограничивать длинну, кроме того в PostgreSQL тип данных с переменной длиной имеют самую низкую производительность.*/
);

CREATE TABLE IF NOT EXISTS car_shop.car_brands(
    brand_id SERIAL PRIMARY KEY,  /*Первичный ключ, автоинкремент по условию задания*/
    brand_name TEXT NOT NULL UNIQUE, /*Бренд записывается в текстовом виде - буквами, т.к. длина заранее не известна - кол-во символов не ограничено, кроме того в PostgreSQL тип данных с переменной длиной имеют самую низкую производительность.*/
    brand_origin TEXT  /*страна производста записывается в текстовом виде - буквами, т.к. длина заранее не известна - кол-во символов не ограничено, кроме того в PostgreSQL тип данных с переменной длиной имеют самую низкую производительность.*/
);

CREATE TABLE IF NOT EXISTS car_shop.colors(
    color_id SERIAL PRIMARY KEY,  /*Первичный ключ, автоинкремент по условию задания*/
    name TEXT NOT NULL UNIQUE /*цвет записывается в текстовом виде - буквами, т.к. длина заранее не известна - кол-во символов не ограничено, кроме того в PostgreSQL тип данных с переменной длиной имеют самую низкую производительность.*/
);

CREATE TABLE IF NOT EXISTS car_shop.car_models(
    model_id  SERIAL PRIMARY KEY, /*Первичный ключ, автоинкремент по условию задания*/
    model_name TEXT NOT NULL UNIQUE, /*название модели записывается буквами и цифрами, поэтому выбран символьный тип данных, для большей производительности длина не ограничена*/
    brand_id INTEGER REFERENCES car_shop.car_brands(brand_id), /*внешний ключ, для соответствия первичному ключу из родительской таблицы используется целочисленный тип данных */
    gasoline_consumption NUMERIC(3, 1) /*по условию значение поля не может быть трехзначным, а после запятой сохраняется одна цифра (судя по сырым данным), numeric выбран для сохранения точности при работе с дробными цифрами */
);

CREATE TABLE IF NOT EXISTS car_shop.model_color(
    model_color_id SERIAL PRIMARY KEY, /*Первичный ключ, автоинкремент по условию задания*/
    model_id INTEGER NOT NULL REFERENCES car_shop.car_models(model_id), /*внешний ключ, для соответствия первичному ключу из родительской таблицы используется целочисленный тип данных */
    color_id INTEGER NOT NULL REFERENCES car_shop.colors(color_id) /*внешний ключ, для соответствия первичному ключу из родительской таблицы используется целочисленный тип данных */
);

CREATE TABLE IF NOT EXISTS car_shop.sales(
    sale_id SERIAL PRIMARY KEY, /*Первичный ключ, автоинкремент по условию задания*/
    model_color_id INTEGER NOT NULL REFERENCES car_shop.model_color(model_color_id), /*внешний ключ, для соответствия первичному ключу из родительской таблицы используется целочисленный тип данных */
    customer_id INTEGER NOT NULL REFERENCES car_shop.clients(customer_id), /*внешний ключ, для соответствия первичному ключу из родительской таблицы используется целочисленный тип данных */
    sale_date DATE NOT NULL CHECK (sale_date <= CURRENT_DATE), /*так как время покупки не фиксируется (судя по сырым данным), для хранения только даты достаточно типа данных DATE, дополнително проверяем, что покупка совершена не позже сегодняшней даты*/
    discount INTEGER DEFAULT 0 CHECK (discount >= 0 AND discount <= 100), /* скидка может быть только целым числом в диапазоне от 0 до 100. */
    price NUMERIC(9, 2)  CHECK (price >= 0)   /*цена может содержать только сотые и не может быть больше семизначной суммы. У numeric повышенная точность при работе с дробными числами, поэтому при операциях c этим типом данных, дробные числа не потеряются.*/
);


 -- Заполнение таблиц
INSERT INTO car_shop.clients(full_name, phone)
SELECT DISTINCT person, phone FROM raw_data.sales;

INSERT INTO car_shop.colors(name) 
SELECT DISTINCT SPLIT_PART(auto, ' ', -1) FROM raw_data.sales ;

INSERT INTO car_shop.car_brands (brand_name, brand_origin)
SELECT DISTINCT SPLIT_PART(auto, ' ', 1), brand_origin FROM raw_data.sales;

INSERT INTO car_shop.car_models (model_name, brand_id, gasoline_consumption)
SELECT DISTINCT 
SPLIT_PART(SUBSTR(auto, STRPOS(auto, ' ')+1), ',', 1),
(SELECT brand_id FROM car_shop.car_brands WHERE brand_name = SPLIT_PART(auto, ' ', 1)),
gasoline_consumption
FROM raw_data.sales;

INSERT INTO car_shop.model_color(model_id, color_id)
SELECT DISTINCT
(SELECT model_id FROM car_shop.car_models WHERE model_name = SPLIT_PART(SUBSTR(auto, STRPOS(auto, ' ')+1), ',', 1)),
(SELECT color_id FROM car_shop.colors WHERE name = SPLIT_PART(auto, ' ', -1))
FROM raw_data.sales; 

INSERT INTO car_shop.sales(model_color_id, customer_id, sale_date,  discount, price)
SELECT  
(SELECT model_color_id FROM car_shop.model_color mod_c
JOIN car_shop.car_models m USING(model_id)
JOIN car_shop.colors c USING(color_id)
WHERE m.model_name = SPLIT_PART(SUBSTR(auto, STRPOS(auto, ' ')+1), ',', 1) AND c.name = SPLIT_PART(auto, ' ', -1)),
(SELECT customer_id FROM car_shop.clients  WHERE full_name = person),
date::date,
discount, 
price
FROM raw_data.sales;



-- Этап 2. Создание выборок

---- Задание 1. Напишите запрос, который выведет процент моделей машин, у которых нет параметра `gasoline_consumption`.

SELECT ROUND(100 - ((COUNT(gasoline_consumption)* 100)/count(*)::numeric)) AS nulls_percentage_gasoline_consumption FROM car_shop.car_models;

---- Задание 2. Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки.

SELECT cb.brand_name, extract(year FROM s.sale_date) AS year, ROUND(AVG(s.price), 2) AS price_avg FROM car_shop.sales s 
JOIN car_shop.model_color mc USING(model_color_id)
JOIN car_shop.car_models cm USING(model_id)
JOIN car_shop.car_brands cb  USING(brand_id)
GROUP BY cb.brand_name, extract(year FROM s.sale_date)
ORDER BY cb.brand_name, extract(year FROM s.sale_date);

---- Задание 3. Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки.

SELECT extract(month FROM sale_date) AS month, extract(year FROM sale_date) AS year, ROUND(AVG(price), 2) AS price_avg FROM car_shop.sales 
WHERE extract(year FROM sale_date) = '2022'
GROUP BY extract(month FROM sale_date), extract(year FROM sale_date)
ORDER BY extract(month FROM sale_date);

---- Задание 4. Напишите запрос, который выведет список купленных машин у каждого пользователя.

SELECT c.full_name AS person, STRING_AGG(CONCAT(cb.brand_name, ' ', cm.model_name), ', ') AS cars  FROM car_shop.sales AS s
JOIN car_shop.clients c USING(customer_id)
JOIN car_shop.model_color mc USING(model_color_id)
JOIN car_shop.car_models cm USING(model_id)
JOIN car_shop.car_brands cb  USING(brand_id)
GROUP BY c.full_name
ORDER BY c.full_name;

---- Задание 5. Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки. Цена в колонке price дана с учётом скидки.

SELECT cb.brand_origin, max(s.price/((100-s.discount)::numeric/100)) AS price_max, min(s.price/((100-s.discount)::numeric/100)) AS price_min FROM car_shop.sales AS s
JOIN car_shop.model_color mc USING(model_color_id)
JOIN car_shop.car_models cm USING(model_id)
JOIN car_shop.car_brands cb  USING(brand_id)
GROUP BY cb.brand_origin;

---- Задание 6. Напишите запрос, который покажет количество всех пользователей из США.
SELECT count(*) FROM car_shop.clients WHERE phone LIKE '+1%';

