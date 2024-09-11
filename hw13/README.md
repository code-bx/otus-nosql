Архитектура Tarantool
=====================

## Установка Tarantool Cartridge CLI

Делал в vagrant, чтобы не мусрить

```bash
(cd ..; ./setup_env.sh)
. ../.pyenv/bin/activate
vagrant up
vagrant ssh
```


## Создание и запуск приложения

```bash
vagrant ssh
git config --global user.email "tarantool-test@example.com"
git config --global user.name "tarantool-test"
cartridge create --name myapp
cd myapp
cartridge build
cartridge start -d
```


## Эксперименты с кластером

Сделал boostrap по tutorial

```bash
cartridge replicasets setup --bootstrap-vshard
cartridge failover set stateful \
  --state-provider stateboard \
  --provider-params '{"uri": "localhost:4401", "password": "***"}'
```

Подключился к Admin UI: http://localhost:8081/admin

Попробовал останов/запуск экземпляров. Посмотрел как на это реагирует UI

```bash
cartridge stop s1-replica s2-master
cartridge start -d s1-replica s2-master
```

Через Web UI вернул роль лидера на s2-master
