Nosql в Яндекс облаке
=====================

## Устанановка клиента ClickHouse

Клиент в docker из официального образа [clickhouse-server](https://hub.docker.com/r/clickhouse/clickhouse-server/tags)

```bash
mkdir clickhouse-client
wget https://storage.yandexcloud.net/cloud-certs/CA.pem \
  --output-document clickhouse-client/CA.pem
ln ../lesson09/tutorial.hits_v1.ddl clickhouse-client
ln ../lesson09/tutorial.visits_v1.ddl clickhouse-client
sudo docker pull clickhouse/clickhouse-server:head-alpine
```


## Создание ClickHouse в облаке

Сети уже были, новые создавать не стал.

Из clickhouse-resource-preset выбрал `b1.medium`. Серьезной нагрузки не
предвидится, для экспериментов хватит.

```bash
yc managed-clickhouse resource-preset list
```

Создание кластера (создается около 5-10 минут)

```bash
(
set -o errexit
DNAME=tutotial
UNAME=test
UPASS=$(pwgen -cn 16 -1)
yc clickhouse cluster create \
  --name otus30 \
  --description "OTUS Lesson30 NoSQL services in Yandex Cloud" \
  --network-name default \
  --clickhouse-resource-preset "b1.medium" \
  --host $(echo "
           zone-id=ru-central1-a
           subnet-name=default-ru-central1-a
           type=clickhouse
           assign-public-ip
         "| awk '/^ *$/ {next} {gsub(/ */,""); printf "%s%s",d,$0; d=","}') \
  --database name=$DNAME \
  --user name=$UNAME,password="$UPASS" \
  --websql-access \
  --datatransfer-access \
  --generate-admin-password
echo "\
user: $UNAME
password: $UPASS
database: $DNAME
host: $(yc managed-clickhouse \
           --format=json host list --cluster-name otus30 \
       | jq --raw-output \
            '.[] | select(.assign_public_ip) | .name' \
       | head -1)
port: 9440
secure: true
openSSL:
  client:
    caConfig: '/etc/clickhouse-client/CA.pem'
" > clickhouse-client/config.yml
)
```


## Эксперименты

### Подключение

Подключение к облачному серверу

```bash
sudo docker run -it --rm --entrypoint /bin/bash \
  --volume $(pwd)/clickhouse-client/:/etc/clickhouse-client/ \
  clickhouse/clickhouse-server:head-alpine
```


### Загрузка данных

Создание таблиц

```console
clickhouse-client \
  --config-file /etc/clickhouse-client/config.yml \
  --queries-file /etc/clickhouse-client/tutorial.hits_v1.ddl \
                 /etc/clickhouse-client/tutorial.visits_v1.ddl
clickhouse-client \
  --config-file /etc/clickhouse-client/config.yml \
  --query='show tables'
```

Импорт данных.

```bash
time wget -O - https://datasets.clickhouse.com/hits/tsv/hits_v1.tsv.xz \
  | unxz -c - \
  | clickhouse-client --query="INSERT INTO tutorial.hits_v1 FORMAT TSV" \
      --max_insert_block_size=10000
```

Таблица hits_v1 Уложилачь за 6 минут 46 сек. Dремя выполнения не так
чтобы показатель, с учетом того, что 802MiB пришли по сети, были
распакованы в 1 поток и ушли обратно в сеть (что-то около 10GiB)

```bash
time wget -O - https://datasets.clickhouse.com/visits/tsv/visits_v1.tsv.xz \
  | unxz -c - \
  | clickhouse-client --query="INSERT INTO tutorial.visits_v1 FORMAT TSV" \
      --max_insert_block_size=10000
```

Табица visits_v1 загрузилась за 3 минуты 5 сек.


### Запросы к данным

Подключение

```bash
clickhouse-client \
  --config-file /etc/clickhouse-client/config.yml
```

Количество строк в таблице

```sql
select count(1) from hits_v1;
```

```
┌─count()─┐
│ 8873898 │
└─────────┘

1 row in set. Elapsed: 0.004 sec.
```

При том, что выбран откровенно тормозной preset время выполнения меньше,
чем было на десктопе в lesson09 (было 0.028 sec стало 0.004 sec, хотя,
при таких величинах может и статистическая погрешность)


Более сложные запросы

```sql
select count(distinct TopLevelDomain) from visits_v1;
```
```
┌─uniqExact(TopLevelDomain)─┐
│                       145 │
└───────────────────────────┘

1 row in set. Elapsed: 0.019 sec. Processed 1.68 million rows, 13.44 MB (87.27 million rows/s., 698.16 MB/s.)
```

Было в lesson09 — 0.075 sec, стало 0.019 сек

```sql
select BrowserCountry, count(1) from visits_v1 group by BrowserCountry;
```
```
101 rows in set. Elapsed: 0.018 sec. Processed 1.68 million rows, 3.36 MB (91.50 million rows/s., 183.01 MB/s.)
```
Было в lesson09 — 0.029, стало 0.018

Последний запрос с join, для полноты эксперимента

```sql
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
```
```
┌─cls────┬─sum(price)─┬─────────avg(price)─┐
│ WTF?!! │ 2205676847 │ 208.97961856484628 │
└────────┴────────────┴────────────────────┘

1 row in set. Elapsed: 2.445 sec. Processed 10.55 million rows, 168.87 MB (4.32 million rows/s., 69.06 MB/s.)
```

На этот раз, медленнее чем в lesson09 (было 2.122 сек, стало стало
2.445). Есть смутные подозрения, что дешевый IO "кончился"


## Уборка мусора

```bash
yc managed-clickhouse cluster delete otus30
```
