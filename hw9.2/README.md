Consul
======

Запуск кластера
===============

Запуск кластера
```
sudo docker-compose up
```

Проверка состояния серверов consul

```
sudo docker-compose exec -- cserv1 consul operator raft list-peers

Node    ID                                    Address          State     Voter  RaftProtocol
cserv2  7ddbff92-7431-22c6-3c75-0f9e98641f2b  172.21.0.3:8300  follower  true   3
cserv3  8e564fc2-7bdd-5094-8222-88de54b4845a  172.21.0.2:8300  leader    true   3
cserv1  2f686356-8401-5974-51c3-2936d6219bac  172.21.0.4:8300  follower  true   3
```

Список узлов в конфигурации

```
sudo docker-compose exec -- cserv1 consul members

Node                Address          Status  Type    Build   Protocol  DC   Partition  Segment
cserv1              172.21.0.4:8301  alive   server  1.15.3  2         dc1  default    <all>
cserv2              172.21.0.3:8301  alive   server  1.15.3  2         dc1  default    <all>
cserv3              172.21.0.2:8301  alive   server  1.15.3  2         dc1  default    <all>
nginx-46bc0681d23d  172.21.0.5:8301  alive   client  1.8.7   2         dc1  default    <default>
nginx-b725ba61909f  172.21.0.7:8301  alive   client  1.8.7   2         dc1  default    <default>
nginx-e20ed3f21668  172.21.0.6:8301  alive   client  1.8.7   2         dc1  default    <default>
```

Адреса "web сервиса"

```
sudo docker exec -it lesson18_nginx_1 host lesson18_nginx_1
lesson18_nginx_1 has address 172.21.0.6

sudo docker exec -it lesson18_nginx_1 host lesson18_nginx_2
lesson18_nginx_2 has address 172.21.0.7

sudo docker exec -it lesson18_nginx_1 host lesson18_nginx_3
lesson18_nginx_3 has address 172.21.0.5


sudo docker exec -it lesson18_nginx_1 host web

web.service.consul has address 172.21.0.7
web.service.consul has address 172.21.0.6
web.service.consul has address 172.21.0.5
```



Балансировка "web сервиса"
```
sudo docker exec -it lesson18_nginx_1 bash -c \
'for i in {1..10}; do curl -s -o- http://$(dig +short @localhost web.service.dc1.consul | head -n1) | html2text; sleep 1; done' \
| sort | uniq -c

 6 Web node 46bc0681d23d
 8 Web node b725ba61909f
 6 Web node e20ed3f21668
```


Отвал ноды
==========

Режем кластер на 2 части:
1. `cserv1`, `cserv2`, `nginx_3`
2. `cserv3`, `nginx_1`, `nginx_2` (без кворума)

```
sudo iptables -I DOCKER-USER 1 -s 172.21.0.2,172.21.0.6,172.21.0.7 \
                               -j DROP
sudo iptables -I DOCKER-USER 1 -s 172.21.0.2,172.21.0.6,172.21.0.7 \
                               -d 172.21.0.2,172.21.0.6,172.21.0.7 \
                               -j ACCEPT
```

Проверка поведения consul
* часть с кворумом
```
sudo docker-compose exec -- cserv1 consul members

Node                Address          Status  Type    Build   Protocol  DC   Partition  Segment
cserv1              172.21.0.4:8301  alive   server  1.15.3  2         dc1  default    <all>
cserv2              172.21.0.3:8301  alive   server  1.15.3  2         dc1  default    <all>
cserv3              172.21.0.2:8301  left    server  1.15.3  2         dc1  default    <all>
nginx-46bc0681d23d  172.21.0.5:8301  alive   client  1.8.7   2         dc1  default    <default>
nginx-b725ba61909f  172.21.0.7:8301  failed  client  1.8.7   2         dc1  default    <default>
nginx-e20ed3f21668  172.21.0.6:8301  failed  client  1.8.7   2         dc1  default    <default>
```
* часть без кворума
```
sudo docker-compose exec -- cserv3 consul members

Node                Address          Status  Type    Build   Protocol  DC   Partition  Segment
cserv1              172.21.0.4:8301  failed  server  1.15.3  2         dc1  default    <all>
cserv2              172.21.0.3:8301  failed  server  1.15.3  2         dc1  default    <all>
cserv3              172.21.0.2:8301  alive   server  1.15.3  2         dc1  default    <all>
nginx-46bc0681d23d  172.21.0.5:8301  failed  client  1.8.7   2         dc1  default    <default>
nginx-b725ba61909f  172.21.0.7:8301  alive   client  1.8.7   2         dc1  default    <default>
nginx-e20ed3f21668  172.21.0.6:8301  alive   client  1.8.7   2         dc1  default    <default>
```

Проверяем поведение DNS
* часть с кворумом
```
sudo docker exec -it lesson18_nginx_3 host web

web.service.consul has address 172.21.0.5
```
* часть без кворума
```
sudo docker exec -it lesson18_nginx_1 host web

web.service.consul has address 172.21.0.6
web.service.consul has address 172.21.0.5
web.service.consul has address 172.21.0.7
```

Проверяем поведение key value
* часть с кворумом
```
sudo docker exec -it lesson18_nginx_3 consul kv put foo bar
Success! Data written to: foo

sudo docker exec -it lesson18_cserv1_1 consul kv get foo bar
bar
```
* часть без кворума
```
sudo docker exec -it lesson18_nginx_2 consul kv put foo baz
Error! Failed writing data: Unexpected response code: 500 (rpc error making call: No cluster leader)
```

Возвращем как было

```
sudo iptables -D DOCKER-USER  -s 172.21.0.2,172.21.0.6,172.21.0.7 \
                              -j DROP
sudo iptables -D DOCKER-USER  -s 172.21.0.2,172.21.0.6,172.21.0.7 \
                              -d 172.21.0.2,172.21.0.6,172.21.0.7 \
                              -j ACCEPT
iptables -D DOCKER 0
```

Проверяем узлы кластера

```
sudo docker-compose exec -- cserv1 consul members

Node                Address          Status  Type    Build   Protocol  DC   Partition  Segment
cserv1              172.21.0.4:8301  alive   server  1.15.3  2         dc1  default    <all>
cserv2              172.21.0.3:8301  alive   server  1.15.3  2         dc1  default    <all>
cserv3              172.21.0.2:8301  alive   server  1.15.3  2         dc1  default    <all>
nginx-46bc0681d23d  172.21.0.5:8301  alive   client  1.8.7   2         dc1  default    <default>
nginx-b725ba61909f  172.21.0.7:8301  alive   client  1.8.7   2         dc1  default    <default>
nginx-e20ed3f21668  172.21.0.6:8301  alive   client  1.8.7   2         dc1  default    <default>
```

Выводы
======

Key-value split-brain устроить не дает, а вот сервисы с настройками по
умолчанию внутри изолированной части без кворума, по прежнему видят в
DNS записи, которые были до разделения.

Я ождал, что consul в изолированной части кластера повырубает все
сервисы, но чуда из коробки не случилось. Возможно, есть настройки на
поиск, которых у меня просто не хватило времени.

По умолчанию, в части регистрации сервисов consul имеется широкий
простор для всевозможных креативных сценариев отказа, при которой
сервисы в изолированной части кластера непредсказуемо меняют свое
состояние за время изоляции и обратная сборка кластера в коситентном
состоянии окажется под вопросом.
