Elasticsearch
=============

## Развертывание Elasticsearch

Установку делал в Docker [по
инструкции](https://www.elastic.co/guide/en/elasticsearch/reference/8.7/docker.html)
в single-node без Kibana и т.п.

docker pull не работает, пришлось собирать образ локально

```console
$ sudo docker build . --tag=elasticsearch:8.7.1
```

Запуск по инструкции

```console
$ sudo docker run --name es01 -p 9200:9200 -it elasticsearch:8.7.1
...
✅ Elasticsearch security features have been automatically configured!
✅ Authentication is enabled and cluster connections are encrypted.

ℹ️  Password for the elastic user (reset with `bin/elasticsearch-reset-password -u elastic`):
  ***
...
```


# Коллекция Postman

Линк на [коллекцию Postman](https://api.postman.com/collections/27410204-ed5000fb-9304-4bd6-a010-50f5110f6b6b?access_key=PMAT-01H0DT41VWRSM31BPR2KVE7WHR)

Коллекция содержит:
* Создание index template с настройками mapping для поля text с поддержкой русского языка
* Добавление трех документов в индекс с именем подпадающим под шаблон имени index emplate
* Запрос документов с нечетким условием поиска
