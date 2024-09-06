ClickHouse
==========

## Установка сервера

Установка в vagrant на основе
[инструкции](https://clickhouse.com/docs/ru/getting-started/tutorial#single-node-setup)

```console
vargant up --provision
```


## Импорт данных

Создание таблиц

```console
clickhouse-client --query "CREATE DATABASE IF NOT EXISTS tutorial"
clickhouse-client --queries-file tutorial.hits_v1.ddl tutorial.visits_v1.ddl
clickhouse-client -d tutorial --query='show tables'

hits_v1
visits_v1
```



Импорт данных

_Похоже, Clickhouse любит, когда памяти от 12-16GiB. На урезанной до 2GiB VM
загрузка пару раз вывалилась с ошибкой OvercommitTracker decision: Query was
selected to stop by OvercommitTracker.. (MEMORY_LIMIT_EXCEEDED)_

_Урезал в config.xml параметры `uncompressed_cache_size` и `mark_cache_size`
до 256M, данные загрузились, но скорость, вроде, несколько поубавилась._


```console
pv --buffer-size=4m hits_v1.tsv.xz \
  | xzcat --threads=`nproc` - \
  | clickhouse-client --query="INSERT INTO tutorial.hits_v1 FORMAT TSV" --max_insert_block_size=10000
802MiB 0:02:55 [4.56MiB/s] [===============================>] 100%

pv --buffer-size=4m visits_v1.tsv.xz \
  | unxz --threads=`nproc` \
  | clickhouse-client --query "INSERT INTO tutorial.visits_v1 FORMAT TSV" --max_insert_block_size=100000
405MiB 0:01:25 [4.76MiB/s] [===============================>] 100%
```

Размер /var/lib/clickhouse вышел 2.9GiB. Больше чем упакованные исходные
данные, но раза в 3-4 меньше, чем распакованные данные (исходный набор 10GiB)


## Запросы к данным

Подключение

```console
clickhouse-client -d tutorial
```

Количество строк в таблице

```console
otus-lesson09 :) select count(1) from visits_v1;
...
┌─count()─┐
│ 1680609 │
└─────────┘

1 row in set. Elapsed: 0.005 sec.

otus-lesson09 :) select count(1) from hits_v1;
...
┌─count()─┐
│ 8873898 │
└─────────┘

1 row in set. Elapsed: 0.028 sec.
```

Более сложные запросы

```console
otus-lesson09 :) select count(distinct TopLevelDomain) from visits_v1;
...
┌─uniqExact(TopLevelDomain)─┐
│                       145 │
└───────────────────────────┘

1 row in set. Elapsed: 0.075 sec. Processed 1.68 million rows, 13.44 MB (22.53 million rows/s., 180.24 MB/s.)

otus-lesson09 :) select BrowserCountry, count(1) from visits_v1 group by BrowserCountry;
...
101 rows in set. Elapsed: 0.029 sec. Processed 1.68 million rows, 3.36 MB (57.43 million rows/s., 114.87 MB/s.)
```

Сам не знаю, что спросил. Хотел посмотреть, как join переваривает. Ответ странный, но быстро
```console
otus-lesson09 :)

with t as (
  select case
         when h.UserID is null then 'Visit'
         when v.UserID is null then 'Hit'
         when h.UserID = v.UserID then 'Both'
         else 'WTF?!!'
         end cls
       , coalesce(h.ParamPrice, v.ParamSumPrice) price
    from visits_v1 v full outer join hits_v1 h on (h.UserID = v.UserID)
)
select cls, sum(price), avg(price)
  from t
 group by cls;

WITH t AS
    (
        SELECT
            multiIf(h.UserID = v.UserID, 'Both', h.UserID IS NULL, 'Visit', v.UserID IS NULL, 'Hit', 'WTF?!!') AS cls,
            coalesce(h.ParamPrice, v.ParamSumPrice) AS price
        FROM visits_v1 AS v
        FULL OUTER JOIN hits_v1 AS h ON h.UserID = v.UserID
    )
SELECT
    cls,
    sum(price),
    avg(price)
FROM t
GROUP BY cls

Query id: 3e41725b-a4fe-4f76-a8ca-b06fd21507e1

┌─cls────┬─sum(price)─┬─────────avg(price)─┐
│ WTF?!! │ 2205676847 │ 208.97961856484628 │
└────────┴────────────┴────────────────────┘

1 row in set. Elapsed: 2.122 sec. Processed 10.55 million rows, 168.87 MB (4.97 million rows/s., 79.58 MB/s.)
```
