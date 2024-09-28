Построение и тестирование высоконагруженного отказоустойчивого кластера Clickhouse
==================================================================================

Кластер ClickHouse 


## Развертывание

Terraform в Yandex Cloud 
Для работы нужна сервисная учетка Yandex Cloud
  https://cloud.yandex.ru/docs/iam/operations/sa/create-access-key

Параметры сервисной учетки сложены в файл `terraform-key.json`, чтобы
terraform не задавал лишних вопросов

```bash
export YC_SERVICE_ACCOUNT_KEY_FILE=.../terraform-key.json
```

Если проект еще не инициализирован

```bash
cd {project_dir}/final_project
terraform init
```

Настройка узлов выполняется ansible в virtualenv внутри проекта.
Если virtualenv еще не настроен:

```bash
cd {project_dir}/
./setup_venv.sh
```

Для настройки этого проекта надо активировать virtualenv и определить
переменные окружения ansible (все лучше, чем каждый раз писать длинную
строку параметров)

```
cd {project_dir}/final_project
. ../.pyenv/bin/activate
export ANSIBLE_CONFIG=$(dirname $PWD)/ansible/ansible.cfg
export ANSIBLE_INVENTORY=$PWD/ansible/terraform.inventory.yml
```

Создание и запуск кластера (минут на 15-20)

```
terraform apply
ansible-playbook ansible/provision.yml
```


## Тестовые данные

Генератор тестовых данных `gen_disk_use.py`. Тестовый набор подделка под
данные о заполнении файловых систем в виде CSV:

 * 352 миллиона строк
 * 19.7 GiB в виде CSV файлов
 * 3.1 GiB в сжатом gzip виде (размещено в S3, чтобы проще было грузить в Clickhouse)


Подключение по ssh несколько витьеватое (более путного, пока, ничего не придумал):

 * IP приходится запрашивать у ansible, например:

 ```bash
 ansible-inventory --host clickhouse1 | jq .ansible_host
 ```

 * Само подключение выгладит так (чтобы не засорять общий `known_hosts`)

 ```bash
 ssh -o UserKnownHostsFile=ansible/terraform.known_hosts yc-user@{ip из ansible}
 ```

Скрипты загрузки данных:
 * Создание БД `create_db_archive.sql`
 * Создание таблицы `tab_diskusage.sql`
 * Грузил из s3 `ins_diskusage.sql`


## Результаты

В процессе загрузки ни один узел не простаивал. После недолгого периода
бурной загрузки, скорость начала заметно проседать. Видимо кончилась память.

При одном шарде в среднем вышла на 7.3MiB/s.

```
0 rows in set. Elapsed: 533.785 sec. Processed 351.35 million rows, 3.42 GB (811.81 thousand rows/s., 7.3 MB/s.)
Peak memory usage: 4.67 GiB.
```

С двумя шардами получилось чуть быстрее, но не стабильно, может на те же 7MiB/s выйти:

```
0 rows in set. Elapsed: 312.558 sec. Processed 352.15 million rows, 3.22 GB (1.13 million rows/s., 10.30 MB/s.)
Peak memory usage: 4.51 GiB.
```

Потребление диска увеличилось с 2.9G до 8.3G. То есть на 20 GiB сырых
данных ушло примерно те же 20 GiB дискового протсранства. Понятно, что
это с учетом репликации, накладных расходов и к данным в ClickHouse
проще обращаться, но чуда не случилось.

В общем-то простой запрос свалился с нехваткой памяти и явно загрузил
только часть узлов.

```
select max(used_bytes) from (select sum(used_bytes) as used_bytes from diskusage group by t);
```

С фильтром по дате отработало, но не быстро. То есть опять без
чудес. Еще странно, что запрос зачем-то перелопатил все строки.

```
select max(used_bytes)
  from (select sum(used_bytes) as used_bytes
          from archive.diskusage
         where t between '2024-09-01' and '2024-09-26' group by t);
```

В обратную сторону работает побыстрее

```
select t
  from archive.diskusage
 where t between '2024-09-26' and '2024-09-01'
 group by t
having sum(used_bytes) = 18710156683065;
```


## Открытые вопросы

Как балансировать или хотябы обходить отказы входных узлов clickhouse;

В интернете предлагают работать по HTTP через nginx или chproxy. Не пробовал.

Сложилось впечатление, что реплики не участвуют в распределенных
запросах, даже на чтение и просто висят мертвык грузом. Можно ли это
обойти не понял.

