Redis
=====

Redis 7.0.11 в Docker ([ссылка на образ](https://hub.docker.com/_/redis))

```
sudo docker run --name otus-nosql-16 -p 6379:6379 -d redis:7.0.11
```

Данные [Electric Vehicle Population
Data](https://catalog.data.gov/dataset/?q=Electric+Vehicle+Population+Data&sort=views_recent+desc&res_format=JSON). Для
воспроизводимости результатов, исходные данные сохранены в файле
`electric-vehicle-population-data.json.xz`

Тесты гонял в python 3. Драйвер [redis-py
4.5.5](https://github.com/redis/redis-py) в локальном virtualenv.

Запуск тестов

```
../setup_env.sh
. ../.pyenv/bin/activate
pytest --durations=0 --durations-min=0 lesson16.py
```

Тест разово считывае данные из json в память (всего 130443
документа). Затем разными способами загружает данные в Redis (функции
`test_otus16_*_write`). После загрузки данных они считываются обратно из
Redis и считается количество документов с группировкой по полю Make
(функции test_otus16_*_count_make).

Эталонный (правильный) результат подсчета сохранен в result_expected. С
ним сравниваем то, что получилось получилось в результате подсчета,
чтобы убедиться, что тест работает правильно

Подсчет времени отдан на откуп pytest

Итоговый результат:

```
==================== test session starts ====================
platform linux -- Python 3.10.6, pytest-7.3.1, pluggy-1.0.0
rootdir: .../otus/nosql/lesson16
plugins: order-1.1.0
collecting ...
collected 8 items

lesson16.py ........                                   [100%]

===================== slowest durations =====================
66.46s call     lesson16.py::test_otus16_str_write
38.34s call     lesson16.py::test_otus16_oset_write
24.10s call     lesson16.py::test_otus16_hset_write
17.85s call     lesson16.py::test_otus16_list_write
 3.85s call     lesson16.py::test_otus16_str_count_make
 1.52s call     lesson16.py::test_otus16_hset_count_make
 1.35s call     lesson16.py::test_otus16_list_count_make
 0.00s call     lesson16.py::test_otus16_oset_count_make
...
 2.40s setup    lesson16.py::test_otus16_str_write
 0.16s teardown lesson16.py::test_otus16_list_count_make
=============== 8 passed in 156.14s (0:02:36) ===============
```
