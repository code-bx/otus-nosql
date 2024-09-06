Couchbase
=========

## Установка

Для развертывания использовал Terrafrom с провайдером Yandex Cloud.
Ansible в качестве provisioner, пока не осилил (не дошли еще руки
virtualenv в проект добавить)

Развертывание
```console
terraform apply
...
Apply complete! Resources: 5 added, 0 changed, 0 destroyed.
```

## Сборка кластера UI

Достал внешний адрес хоста `cb1` из вывода
```
yc compute instance list
```

На удивление, VM торчит всеми портами наружу. Поэтому пошел сразу на порт 8091 пока никто не вскрыл.

### Setup New Cluster

 * Cluster Name: otus07
 * Admin User Name: admin
 * Password: `$(pwgen -cny 6 1 | tee pass.txt)`

### Couchbase > New Cluster > Configure

 * Host Name / IP Address = cb1.ru-central1.internal
 * IP Family Preference = IPv4
 * Service Memory Quotas
   * Data = 1693
   * Query
   * Index = 512
   * Search = 256
   * Остальные отключены
 * Index Storage Setting = Standard Global Secondary
 * Все пути = /opt/couchbase/var/lib/couchbase/data
 * Java Runtime Path = не задан

### Servers > Add Server

 * Hostname/IP Address: cb{2-5}.ru-central1.internal
 * Username: admin
 * Password: тот же что на первом узле
 * Services: везде только Data, Query, Index, Search

По окончании добавления серверов. Rebalance


## Загрузка тестовых данных

Buckets > sample bucket > beer sample

По завершении загрузки Buckets > beer-sample:
 * Items: 7303
 * RAM used/quota: 69.9 / 1000 MiB (менять квоты не стал)
 * disk used: 27.6 MiB

Тестовый запрос Query
```
select type, count(1) from `beer-sample`.`_default`.`_default` data group by type
```

```json
[
  {
    "$1": 1412,
    "type": "brewery"
  },
  {
    "$1": 5891,
    "type": "beer"
  }
]
```

## Проверка реакции на отказ

Выключил узел cb2 через UI

В Servers засветилось, что узел 2 недоступен.

Пока не случился автоматический Failover запустил тестовый запрос.

Заметно призадумалось (по ощущениям, больше 10 секунд), после чего
выдало диковатый результат, даже близко не похожий на результат
при первом запуске запроса (видимо, пример Eventual Consistency):
```json
[
  {
    "$1": 1,
    "type": "brewery"
  },
  {
    "$1": 4,
    "type": "beer"
  }
]
```

В Results выдало предупреждение
```json
[
  {
    "code": 12008,
    "msg": "Error performing bulk get operation - cause: {2 errors, ... i/o timeout}",
    "retry": true
  }
]
```

После того, как случился автоматический Failover запустил запрос еще раз.
На этот раз выдало ответ меньше чем за секунду и результат совпал с иходным.

Включил узел cb2 как было.

На Servers появилось сообщение, что cb2 ожил и его можно добавить обратно.
Нажал "Add Back: Delta Recovery". Не сразу сообразил, что для фактического
возврата надо нажать Rebalance. После нажатия Rebalance узел вернулся в
калстер примерно за 40 секунд

Еще раз попробовал тестовый запрос. Интересно, но запрос отработал примерно на
100ms быстрее. Чем прошлый раз с 4 узлами. Решил позапускать запрос еще
несколько раз. Предоположение, что ускорение случилось из-за возврата не
подтвердилось. Время ответа плавает в пределах 0.8-2s и от чего зависит не
ясно (может соседи по облаку CPU съели).


## Завершение сесси

На выходе, чтобы зря деньги не тратить
```
terraform destroy
```
