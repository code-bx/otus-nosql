Etcd
====

## Запуск кластера

Кластер разворачивал в Vagrant с помощью Ansible

```
../setup_env.sh
. ../.pyenv/bin/activate
vagrant up
```

Состояния кластера

```
vagrant ssh etcd1 -- env ETCDCTL_API=3 etcdctl endpoint status -w table --cluster=true
+-------------------+------------------+---------+---------+-----------+-----------+------------+
|     ENDPOINT      |        ID        | VERSION | DB SIZE | IS LEADER | RAFT TERM | RAFT INDEX |
+-------------------+------------------+---------+---------+-----------+-----------+------------+
| http://etcd1:2379 | dd70c26b41db9252 |  3.3.25 |   20 kB |      true |        23 |         10 |
| http://etcd2:2379 | 9a98e8c6228841fc |  3.3.25 |   20 kB |     false |        23 |         10 |
| http://etcd3:2379 | f3f477c37784a130 |  3.3.25 |   20 kB |     false |        23 |         10 |
+-------------------+------------------+---------+---------+-----------+-----------+------------+
```


## Отказ одного узла

Выключение одного из узлов один из узлов

```
vagrant halt -f etcd3
```

Проверка ракции на команды работы с kv

```
vagrant ssh etcd1 -- env ETCDCTL_API=3 etcdctl put key value
OK
vagrant ssh etcd2 -- env ETCDCTL_API=3 etcdctl get key
key
value
```

Перезапуск узла

```
vagrant up etcd3
```

После перезапуска 3го узла кластер развалился примерно на 2 минуты. В логах были сообщения:

```
...health check for peer ... could not connect: dial tcp: i/o timeout (prober "ROUND_TRIPPER_RAFT_MESSAGE
```

Потом все нормализовалось. Что это было, не понятно. Может странности
vagrant-libvirt, а может поведение etcd.


## Развал 2 части

Развал кластера на 2 части:

```
vagrant ssh etcd2 -- sudo iptables -A INPUT -s etcd1 -j DROP
vagrant ssh etcd2 -- sudo iptables -A INPUT -s etcd3 -j DROP
vagrant ssh etcd2 -- sudo iptables -A OUTPUT -d etcd1 -j DROP
vagrant ssh etcd2 -- sudo iptables -A OUTPUT -d etcd3 -j DROP
```

Статус кластера

```
vagrant ssh etcd1 -- etcdctl cluster-health
failed to check the health of member 9a98e8c6228841fc on http://etcd2:2379: Get "http://etcd2:2379/health": dial tcp 192.168.121.144:2379: i/o timeout
member 9a98e8c6228841fc is unreachable: [http://etcd2:2379] are all unreachable
member dd70c26b41db9252 is healthy: got healthy result from http://etcd1:2379
member f3f477c37784a130 is healthy: got healthy result from http://etcd3:2379
cluster is degraded
(otus-nosql) andrey@andromeda:~/project/otus/nosql/lesson17$

vagrant ssh etcd2 -- etcdctl cluster-health
member 9a98e8c6228841fc is unhealthy: got unhealthy result from http://etcd2:2379
failed to check the health of member dd70c26b41db9252 on http://etcd1:2379: Get "http://etcd1:2379/health": dial tcp 192.168.121.249:2379: i/o timeout
member dd70c26b41db9252 is unreachable: [http://etcd1:2379] are all unreachable
failed to check the health of member f3f477c37784a130 on http://etcd3:2379: Get "http://etcd3:2379/health": dial tcp 192.168.121.237:2379: i/o timeout
member f3f477c37784a130 is unreachable: [http://etcd3:2379] are all unreachable
cluster is unavailable
```

Реакция части с кворумом на команды:

```
vagrant ssh etcd1 -- env ETCDCTL_API=3 etcdctl put key value2
OK
vagrant ssh etcd3 -- env ETCDCTL_API=3 etcdctl get key
key
value2
```

Реакция изолированной части на команды

```
time vagrant ssh etcd2 -- env ETCDCTL_API=3 etcdctl get key
{"level":"warn","ts":"2023-06-14T01:02:56.818Z","caller":"clientv3/retry_interceptor.go:62","msg":"retrying of unary invoker failed","target":"endpoint://client-551baba0-45ae-4831-a509-30692c6f9ebf/127.0.0.1:2379","attempt":0,"error":"rpc error: code = DeadlineExceeded desc = context deadline exceeded"}
Error: context deadline exceeded

real    0m7,353s
user    0m1,832s
sys     0m0,174s
```

Восстановление связанности

```
vagrant ssh etcd2 -- sudo iptables -F INPUT
vagrant ssh etcd2 -- sudo iptables -F OUTPUT
```

Состояние кластера (на этот раз временного развала не было)

```
vagrant ssh etcd1 -- etcdctl cluster-health
member 9a98e8c6228841fc is healthy: got healthy result from http://etcd2:2379
member dd70c26b41db9252 is healthy: got healthy result from http://etcd1:2379
member f3f477c37784a130 is healthy: got healthy result from http://etcd3:2379
cluster is healthy

vagrant ssh etcd1 -- env ETCDCTL_API=3 etcdctl endpoint status -w table --cluster=true
+-------------------+------------------+---------+---------+-----------+-----------+------------+
|     ENDPOINT      |        ID        | VERSION | DB SIZE | IS LEADER | RAFT TERM | RAFT INDEX |
+-------------------+------------------+---------+---------+-----------+-----------+------------+
| http://etcd2:2379 | 9a98e8c6228841fc |  3.3.25 |  1.6 MB |     false |       361 |        799 |
| http://etcd1:2379 | dd70c26b41db9252 |  3.3.25 |  1.6 MB |      true |       361 |        799 |
| http://etcd3:2379 | f3f477c37784a130 |  3.3.25 |  1.6 MB |     false |       361 |        799 |
+-------------------+------------------+---------+---------+-----------+-----------+------------+
```

Проверка значения ключа на выпадавшем узле, которое было записано во время отказа

```
time vagrant ssh etcd2 -- env ETCDCTL_API=3 etcdctl get key
key
value2

real    0m2,356s
user    0m1,860s
sys     0m0,149s
```


## Полный отказ кластера

Проверка полого отказ кластера — перезапуск всех узлов разом. (Не каждый
кластер готов автоматически подняться после такого отказа).

```
vagrant halt -f
vagrant up
```

После запуска кластер развален

```
date; vagrant ssh etcd1 -- etcdctl cluster-health
2023-06-14 06:14:01
failed to check the health of member 9a98e8c6228841fc on http://etcd2:2379: Get "http://etcd2:2379/health": dial tcp: i/o timeout
member 9a98e8c6228841fc is unreachable: [http://etcd2:2379] are all unreachable
member dd70c26b41db9252 is healthy: got healthy result from http://etcd1:2379
failed to check the health of member f3f477c37784a130 on http://etcd3:2379: Get "http://etcd3:2379/health": dial tcp: i/o timeout
member f3f477c37784a130 is unreachable: [http://etcd3:2379] are all unreachable
cluster is degraded
```

Примерно через минуту, состояние кластера восстановилось

```
date "+%Y-%m-%d %H:%M:%S"; for n in 1 2 3; do vagrant ssh etcd$n -- etcdctl cluster-health; done
2023-06-14 06:15:24
member 9a98e8c6228841fc is healthy: got healthy result from http://etcd2:2379
member dd70c26b41db9252 is healthy: got healthy result from http://etcd1:2379
member f3f477c37784a130 is healthy: got healthy result from http://etcd3:2379
cluster is healthy
member 9a98e8c6228841fc is healthy: got healthy result from http://etcd2:2379
member dd70c26b41db9252 is healthy: got healthy result from http://etcd1:2379
member f3f477c37784a130 is healthy: got healthy result from http://etcd3:2379
cluster is healthy
member 9a98e8c6228841fc is healthy: got healthy result from http://etcd2:2379
member dd70c26b41db9252 is healthy: got healthy result from http://etcd1:2379
member f3f477c37784a130 is healthy: got healthy result from http://etcd3:2379
cluster is healthy
```
