Cassandra: CQL and Java, Scala API
==================================

## Cassandra кластер в docker

Запуск кластера cassandra из 3х узлов:

```
sudo docker-compose up
```

Обычные (не seed) узлы в compose имеют свойство, иногда, падать с
ошибкой `Bootstrap Token collision`. При повторном запуске, узел
стартует нормально. Предположительно, проблема связана с тем, что один и
тот же образ запускается практически в одно и то же время из-за чего
алгоритм генерации токенов выдает дубли. Понятно, restart: always
проблему решает, но это не очень спортивно.

Проверка статуса кластера

```
sudo docker exec -it lesson11_cseed_1 /bin/bash
```

```
nodetool status
Datacenter: datacenter1
=======================
Status=Up/Down
|/ State=Normal/Leaving/Joining/Moving
--  Address     Load        Tokens  Owns (effective)  Host ID                               Rack
UN  172.20.0.3  120.79 KiB  16      76.0%             aef6026a-cb48-4867-910d-e782d30cfe60  rack1
UN  172.20.0.4  109.32 KiB  16      59.3%             2ed577cb-f6e8-47d7-9e44-bf7e96bcb32b  rack1
UN  172.20.0.2  109.4 KiB   16      64.7%             d95ce764-db70-4554-b266-23aee9cffee2  rack1
```

В качестве клиента использовал cqlsh на seed node:

```
sudo docker exec -it lesson11_cseed_1 /opt/cassandra/bin/cqlsh
```

## И заполнение keyspace

Создание keyspace

```
cqlsh> create keyspace test WITH replication = {'class': 'SimpleStrategy', 'replication_factor':2};
cqlsh> desc test;
CREATE KEYSPACE test WITH replication = {'class': 'SimpleStrategy', 'replication_factor': '2'}  AND durable_writes = true;
cqlsh> use test;
cqlsh:test>
```

Создание таблиц:

```
CREATE TABLE devices (
  dev_id int primary key,
  site_id int,
  info text
  );
CREATE TABLE metrics (
  dev_id         int,
  site_id        int,
  sample_date    date,
  tstamp          timestamp,
  value          float,
  PRIMARY KEY ((dev_id, sample_date), tstamp)
  );
```

Загрузка данных:

```
insert into devices (dev_id, site_id, info) values (1, 1, 'host1');
insert into devices (dev_id, site_id, info) values (2, 1, 'host2');
insert into devices (dev_id, site_id, info) values (3, 2, 'host3');

insert into metrics (dev_id, site_id, sample_date, tstamp, value)
values (1, 1, '2023-05-01', '2023-05-01 00:00', 100);
insert into metrics (dev_id, site_id, sample_date, tstamp, value)
values (1, 1, '2023-05-01', '2023-05-01 01:00', 200);
insert into metrics (dev_id, site_id, sample_date, tstamp, value)
values (1, 1, '2023-05-01', '2023-05-01 02:00', 500);
insert into metrics (dev_id, site_id, sample_date, tstamp, value)
values (1, 1, '2023-05-02', '2023-05-02 00:00', 10);
insert into metrics (dev_id, site_id, sample_date, tstamp, value)
values (1, 1, '2023-05-02', '2023-05-02 04:00', 1000);
insert into metrics (dev_id, site_id, sample_date, tstamp, value)
values (1, 1, '2023-05-02', '2023-05-02 07:00', 300);

insert into metrics (dev_id, site_id, sample_date, tstamp, value)
values (2, 1, '2023-05-01', '2023-05-01 10:00', 120);
insert into metrics (dev_id, site_id, sample_date, tstamp, value)
values (2, 1, '2023-05-01', '2023-05-01 11:00', 220);
insert into metrics (dev_id, site_id, sample_date, tstamp, value)
values (2, 1, '2023-05-01', '2023-05-01 12:00', 520);
insert into metrics (dev_id, site_id, sample_date, tstamp, value)
values (2, 1, '2023-05-02', '2023-05-02 10:00', 20);
insert into metrics (dev_id, site_id, sample_date, tstamp, value)
values (2, 1, '2023-05-02', '2023-05-02 14:00', 1020);
insert into metrics (dev_id, site_id, sample_date, tstamp, value)
values (2, 1, '2023-05-02', '2023-05-02 17:00', 320);

insert into metrics (dev_id, site_id, sample_date, tstamp, value)
values (3, 2, '2023-05-01', '2023-05-01 03:00', 23);
insert into metrics (dev_id, site_id, sample_date, tstamp, value)
values (3, 2, '2023-05-01', '2023-05-01 04:00', 33);
insert into metrics (dev_id, site_id, sample_date, tstamp, value)
values (3, 2, '2023-05-01', '2023-05-01 05:00', 53);
insert into metrics (dev_id, site_id, sample_date, tstamp, value)
values (3, 2, '2023-05-02', '2023-05-02 03:00', 33);
insert into metrics (dev_id, site_id, sample_date, tstamp, value)
values (3, 2, '2023-05-02', '2023-05-02 07:00', 123);
insert into metrics (dev_id, site_id, sample_date, tstamp, value)
values (3, 2, '2023-05-02', '2023-05-02 10:00', 43);
```

Создание вторичного индекса по site_id

```
create index metrics_site on metrics (site_id);
```

## Запросы

Запрос метрик конкретного замера по primary key:

```
select * from metrics where dev_id = 2 and sample_date = '2023-05-02' and tstamp = '2023-05-02 10:00';

 dev_id | sample_date | tstamp                          | site_id | value
--------+-------------+---------------------------------+---------+-------
      2 |  2023-05-02 | 2023-05-02 10:00:00.000000+0000 |       1 |    20
```

Запрос метрик секции целиком по partition key:

```
select * from metrics where dev_id = 3 and sample_date = '2023-05-02' order by tstamp;

 dev_id | sample_date | tstamp                          | site_id | value
--------+-------------+---------------------------------+---------+-------
      3 |  2023-05-02 | 2023-05-02 03:00:00.000000+0000 |       2 |    33
      3 |  2023-05-02 | 2023-05-02 07:00:00.000000+0000 |       2 |   123
      3 |  2023-05-02 | 2023-05-02 10:00:00.000000+0000 |       2 |    43
```

Запрос по диапазону primary key неудобный:

```
select * from metrics
 where dev_id = 2 and sample_date in ('2023-05-01','2023-05-02')
   and tstamp >= '2023-05-01 11:15' and tstamp <= '2023-05-02 15:00';

 dev_id | sample_date | tstamp                          | site_id | value
--------+-------------+---------------------------------+---------+-------
      2 |  2023-05-01 | 2023-05-01 12:00:00.000000+0000 |       1 |   520
      2 |  2023-05-02 | 2023-05-02 10:00:00.000000+0000 |       1 |    20
      2 |  2023-05-02 | 2023-05-02 14:00:00.000000+0000 |       1 |  1020
```

Запрос по вторичному индексу (Работает, но даже отфильтровать по
диапазону дат уже проблема без allow fintering. Видать плохой индекс):

```
select * from metrics where site_id = 1;

 dev_id | sample_date | tstamp                          | site_id | value
--------+-------------+---------------------------------+---------+-------
      1 |  2023-05-02 | 2023-05-02 00:00:00.000000+0000 |       1 |    10
      1 |  2023-05-02 | 2023-05-02 04:00:00.000000+0000 |       1 |  1000
      1 |  2023-05-02 | 2023-05-02 07:00:00.000000+0000 |       1 |   300
      2 |  2023-05-02 | 2023-05-02 10:00:00.000000+0000 |       1 |    20
      2 |  2023-05-02 | 2023-05-02 14:00:00.000000+0000 |       1 |  1020
      2 |  2023-05-02 | 2023-05-02 17:00:00.000000+0000 |       1 |   320
      1 |  2023-05-01 | 2023-05-01 00:00:00.000000+0000 |       1 |   100
      1 |  2023-05-01 | 2023-05-01 01:00:00.000000+0000 |       1 |   200
      1 |  2023-05-01 | 2023-05-01 02:00:00.000000+0000 |       1 |   500
      2 |  2023-05-01 | 2023-05-01 10:00:00.000000+0000 |       1 |   120
      2 |  2023-05-01 | 2023-05-01 11:00:00.000000+0000 |       1 |   220
      2 |  2023-05-01 | 2023-05-01 12:00:00.000000+0000 |       1 |   520
```
