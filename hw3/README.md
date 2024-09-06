Оптимизация производительности mongodb
======================================


## Шардированный кластер

Сборка кластера (вменяемого provision в docker compose не нашел, сделал скриптом)

```bash
./docker-provision.sh
```

Подключение к кластеру суперпользователем для проверки

```bash
sudo docker run -it --network lesson06_default --rm mongo:6.0.5-jammy \
    mongosh --host lesson06_mongos_1 admin -u root --authenticationDatabase admin
```


## Загрузка данных

По аналогии с lesson03 загрузка sample_mllix с [GitHub](https://github.com/mcampo2/mongodb-sample-databases)
```bash
(
user=root
read -sp "$user password: " pass; echo
for file in comments.json movies.json sessions.json theaters.json users.json; do
  base_url=https://github.com/mcampo2/mongodb-sample-databases/raw/master/sample_mflix
  [ -f $file ] || wget $base_url/$file
  mongoimport --drop --db otus --collection "$(basename $file .json)" \
    --type=json --file $file \
    --host lesson06_mongos_1 \
    --authenticationDatabase "admin" -u $user -p "$pass"
done
)
```

Вся база попала primary shard (в данном случае в shard3)

```console
[direct: mongos] admin> sh.status()
...
databases
[
 ...
 {
    database: {
      _id: 'otus',
      primary: 'shard3',
      partitioned: false,
      version: {
        uuid: new UUID("352cb38b-ab68-4614-9666-23463b50290a"),
        timestamp: Timestamp({ t: 1683748680, i: 1 }),
        lastMod: 1
      }
    },
    collections: {}
  }
]
```

Уменьшил размер chunksize (база всего около 30M)

```console
[direct: mongos] admin> use config
[direct: mongos] config> db.settings.updateOne(
...    { _id: "chunksize" },
...    { $set: { _id: "chunksize", value: 1 } },
...    { upsert: true }
... )
{
  acknowledged: true,
  insertedId: 'chunksize',
  matchedCount: 0,
  modifiedCount: 0,
  upsertedCount: 1
}
```

Включил шардирование на базу (данные так и остались в shard3)

```console
sh.enableSharding("otus")
```

Самая большая коллекция comments. Но из полей хотябы отдаленно пригодных для
шардирования у нее только movie_id. Допустим, в основном комментарии смотрят
на странице фильмов, а у пользователей возможности смотреть все свои
комментариий нет или она не нужна редко.

```console
[direct: mongos] otus> db.comments.countDocuments()
50304
[direct: mongos] otus> db.comments.find().limit(1)
[
  {
    _id: ObjectId("5a9427648b0beebeb69579d3"),
    name: 'Cameron Duran',
    email: 'cameron_duran@fakegmail.com',
    movie_id: ObjectId("573a1390f29313caabcd4217"),
    text: 'Quasi dicta culpa asperiores quaerat perferendis neque. Est animi pariatur impedit itaque exercitationem.',
    date: ISODate("1983-04-27T20:39:15.000Z")
  }
]
```

Напрямую шардирование по `movie_id` подходит плохо, так как в нем хранится
ObjectId, который растет вправо. Поиска по диапазону movie_id также не
предвидится. Поэтому сделал хэшированный индекс по `movie_id`, он раскидает
значения более равномерно.

```console
[direct: mongos] otus> db.comments.createIndex( { movie_id: "hashed" } )
movie_id_hashed
[direct: mongos] otus> sh.shardCollection( "otus.comments", { movie_id : "hashed" } )
{
  collectionsharded: 'otus.comments',
  ok: 1,
  '$clusterTime': {
    clusterTime: Timestamp({ t: 1683914480, i: 5 }),
    signature: {
      hash: Binary(Buffer.from("dd3305c78cac6380345d589d5a1e586ed33f338a", "hex"), 0),
      keyId: Long("7231278673536483329")
    }
  },
  operationTime: Timestamp({ t: 1683914480, i: 1 })
}
[direct: mongos] otus> sh.status()
...
---
databases
[
  {
    database: { _id: 'config', primary: 'config', partitioned: true },
    collections: {
      'config.system.sessions': {
        shardKey: { _id: 1 },
        unique: false,
        balancing: true,
        chunkMetadata: [ { shard: 'shard1', nChunks: 1024 } ],
        chunks: [
          'too many chunks to print, use verbose if you want to force print'
        ],
        tags: []
      }
    }
  },
  {
    database: {
      _id: 'otus',
      primary: 'shard3',
      partitioned: false,
      version: {
        uuid: new UUID("352cb38b-ab68-4614-9666-23463b50290a"),
        timestamp: Timestamp({ t: 1683748680, i: 1 }),
        lastMod: 1
      }
    },
    collections: {
      'otus.comments': {
        shardKey: { movie_id: 'hashed' },
        unique: false,
        balancing: true,
        chunkMetadata: [
          { shard: 'shard1', nChunks: 4 },
          { shard: 'shard2', nChunks: 4 },
          { shard: 'shard3', nChunks: 1 }
        ],
        chunks: [
          { min: { movie_id: MinKey() }, max: { movie_id: Long("-8056126128858135816") }, 'on shard': 'shard2', 'last modified': Timestamp({ t: 2, i: 0 }) },
          { min: { movie_id: Long("-8056126128858135816") }, max: { movie_id: Long("-6449895467688482365") }, 'on shard': 'shard1', 'last modified': Timestamp({ t: 3, i: 0 }) },
          { min: { movie_id: Long("-6449895467688482365") }, max: { movie_id: Long("-5079304911544821241") }, 'on shard': 'shard2', 'last modified': Timestamp({ t: 4, i: 0 }) },
          { min: { movie_id: Long("-5079304911544821241") }, max: { movie_id: Long("-3952917043292340703") }, 'on shard': 'shard1', 'last modified': Timestamp({ t: 5, i: 0 }) },
          { min: { movie_id: Long("-3952917043292340703") }, max: { movie_id: Long("-2631295351711932400") }, 'on shard': 'shard2', 'last modified': Timestamp({ t: 6, i: 0 }) },
          { min: { movie_id: Long("-2631295351711932400") }, max: { movie_id: Long("-994621877658983387") }, 'on shard': 'shard1', 'last modified': Timestamp({ t: 7, i: 0 }) },
          { min: { movie_id: Long("-994621877658983387") }, max: { movie_id: Long("63915987764290778") }, 'on shard': 'shard2', 'last modified': Timestamp({ t: 8, i: 0 }) },
          { min: { movie_id: Long("63915987764290778") }, max: { movie_id: Long("1332568311745411085") }, 'on shard': 'shard1', 'last modified': Timestamp({ t: 9, i: 0 }) },
          { min: { movie_id: Long("1332568311745411085") }, max: { movie_id: MaxKey() }, 'on shard': 'shard3', 'last modified': Timestamp({ t: 9, i: 1 }) }
        ],
        tags: []
      }
    }
  }
]
```

Видно что коллекция разъехалась по шардам. Правда, вышло кривовато и в shard3
попало меньше чанков, видимо хеш функция разбрасывает значения не так
равномерно.

Проверяем что запросы с movie_id обращаются к разным шардам:

```console
[direct: mongos] otus> db.comments.find({ movie_id: { $eq: ObjectId("573a1399f29313caabcec24c") }}).explain()
...
{
  queryPlanner: {
    mongosPlannerVersion: 1,
    winningPlan: {
      stage: 'SINGLE_SHARD',
      shards: [
        {
          shardName: 'shard3',
 ...
 [direct: mongos] otus> db.comments.find({ movie_id: { $eq: ObjectId("573a1393f29313caabcdc04d") }}).explain()
{
  queryPlanner: {
    mongosPlannerVersion: 1,
    winningPlan: {
      stage: 'SINGLE_SHARD',
      shards: [
        {
          shardName: 'shard1',
...
```


## Иммитация отказов

mongos не показывает состояние отдельных реплик, поэтому для экспериментов
взял shard1.

Поскольку root остался в config базе, пришлось подключиться локально на
primary и сделать локального пользователя

```console
sudo docker exec -it lesson06_shard1_1 bash
mongosh --host localhost
shard1 [direct: primary] test> use admin
switched to db admin
shard1 [direct: primary] admin> db.createUser({user: 'root', pwd: 'otus_r00t', roles: [ 'root' ]})
{
  ok: 1,
  lastCommittedOpTime: Timestamp({ t: 1683917464, i: 1 }),
  '$clusterTime': {
    clusterTime: Timestamp({ t: 1683917464, i: 4 }),
    signature: {
      hash: Binary(Buffer.from("953a6317a31fdf45f028b76110185ebe4c012b1c", "hex"), 0),
      keyId: Long("7231278673536483329")
    }
  },
  operationTime: Timestamp({ t: 1683917464, i: 4 })
}
```

Подключился к replicaset удаленно

```bash
sudo docker run -it --network lesson06_default --rm mongo:6.0.5-jammy \
    mongosh --host shard1/lesson06_shard1_1,lesson06_shard1_2,lesson06_shard1_3 \
      -u root --authenticationDatabase admin
```

Провеяем статус replicaSet

```console
shard1 [primary] admin> rs.status().members.map(function(m) {return {"name": m.name, "stateStr": m.stateStr} } )
[
  { name: 'lesson06_shard1_1:27017', stateStr: 'PRIMARY' },
  { name: 'lesson06_shard1_2:27017', stateStr: 'SECONDARY' },
  { name: 'lesson06_shard1_3:27017', stateStr: 'SECONDARY' }
]
```

Пробуем убить primary узел

```console
sudo docker kill lesson06_shard1_1
```

Проверяем повторно проверяем статуc

```console
shard1 [primary] admin> rs.status().members.map(function(m) {return {"name": m.name, "stateStr": m.stateStr} } )
shard1 [primary] admin> rs.status().members.map(function(m) {return {"name": m.name, "stateStr": m.stateStr} } )
[
  {
    name: 'lesson06_shard1_1:27017',
    stateStr: '(not reachable/healthy)'
  },
  { name: 'lesson06_shard1_2:27017', stateStr: 'PRIMARY' },
  { name: 'lesson06_shard1_3:27017', stateStr: 'SECONDARY' }
]
```

Добавляем тестовые данные

```console
shard1 [primary] admin> use test
switched to db test
shard1 [primary] test> db.test.insertOne({ name: "a", value: 1 })
{
  acknowledged: true,
  insertedId: ObjectId("645e8fc10a55b0122cc54d8e")
}
shard1 [primary] test> db.test.insertOne({ name: "a", value: 2 }, {writeConcern: {w:"majority"}})
{
  acknowledged: true,
  insertedId: ObjectId("645e8fc90a55b0122cc54d8f")
}
```

Запись работает, хотя один узел не доступен.

Добил 3й shard (который secondary). Оболочка вообще перестала откликаться при подключении к replicaset:

```
MongoServerSelectionError: getaddrinfo ENOTFOUND lesson06_shard1_1
```

Удалось подключиться только напрямую к выжившему шарду:

```bash
sudo docker run -it --network lesson06_default --rm mongo:6.0.5-jammy\
  mongosh --host lesson06_shard1_2 -u root --authenticationDatabase admin
```

Он ушел в роль SECONDARY

```
shard1 [direct: secondary] test> rs.status().members.map(function(m) {return {"name": m.name, "stateStr": m.stateStr} } )
[
  {
    name: 'lesson06_shard1_1:27017',
    stateStr: '(not reachable/healthy)'
  },
  { name: 'lesson06_shard1_2:27017', stateStr: 'SECONDARY' },
  {
    name: 'lesson06_shard1_3:27017',
    stateStr: '(not reachable/healthy)'
  }
]
```

Поднял 3й узел. Зараборало подключение к replicaset. Статус ожил:

```console
shard1 [primary] test> rs.status().members.map(function(m) {return {"name": m.name, "stateStr": m.stateStr} } )
[
  {
    name: 'lesson06_shard1_1:27017',
    stateStr: '(not reachable/healthy)'
  },
  { name: 'lesson06_shard1_2:27017', stateStr: 'PRIMARY' },
  { name: 'lesson06_shard1_3:27017', stateStr: 'SECONDARY' }
]
```

Пререзапустил 1й узел. После запуска, он захватил роль PRIMARY, так как ему при настройке был выставлен более высокий приоритет.

```console
shard1 [primary] test> rs.status().members.map(function(m) {return {"name": m.name, "stateStr": m.stateStr} } )
[
  { name: 'lesson06_shard1_1:27017', stateStr: 'PRIMARY' },
  { name: 'lesson06_shard1_2:27017', stateStr: 'SECONDARY' },
  { name: 'lesson06_shard1_3:27017', stateStr: 'SECONDARY' }
]
```


## Настрока ролевого доступа

root уже есть, создаем второго пользователя с ограниченной ролью только на чтение:

```console
use test
shard1 [primary] test> db.createRole({
...   role: "myReadRole",
...   privileges: [{
...     resource: { db: "test", collection: "test" },
...     actions: ["find"]
...   }],
...   roles: []
... })
{
  ok: 1,
  lastCommittedOpTime: Timestamp({ t: 1683920156, i: 1 }),
  '$clusterTime': {
    clusterTime: Timestamp({ t: 1683920158, i: 1 }),
    signature: {
      hash: Binary(Buffer.from("665983fc60308c18a1a556c5eafe6309a98ca196", "hex"), 0),
      keyId: Long("7231278673536483329")
    }
  },
  operationTime: Timestamp({ t: 1683920158, i: 1 })
}
shard1 [primary] test> db.createUser({user: 'reader', pwd: 'readerpw', roles: [ 'myReadRole' ]})
{
  ok: 1,
  lastCommittedOpTime: Timestamp({ t: 1683920196, i: 2 }),
  '$clusterTime': {
    clusterTime: Timestamp({ t: 1683920206, i: 1 }),
    signature: {
      hash: Binary(Buffer.from("5ad0fb9869ae5874c283055a68f42394c07e15e8", "hex"), 0),
      keyId: Long("7231278673536483329")
    }
  },
  operationTime: Timestamp({ t: 1683920206, i: 1 })
}
```

Переподключился ограниченным пользователем:

```console
sudo docker run -it --network lesson06_default --rm mongo:6.0.5-jammy \
  mongosh --host shard1/lesson06_shard1_1,lesson06_shard1_2,lesson06_shard1_3 \
  -u reader --authenticationDatabase test
```

Проверяем, что может пользователь

```console
shard1 [primary] test> show collections
MongoServerError: not authorized on test to execute command { listCollections: 1, filter: {}, cursor: {}, nameOnly: true, authorizedCollections: false, lsid: { id: UUID("15a08a38-f8d7-41a8-86ba-a667147a2a5c") }, $clusterTime: { clusterTime: Timestamp(1683920366, 3), signature: { hash: BinData(0, 273048BD4E94395E6A8333A0B7541C540ECA004E), keyId: 7231278673536483329 } }, $db: "test", $readPreference: { mode: "primaryPreferred" } }
shard1 [primary] test> db.test.find()
[
  { _id: ObjectId("645e8fc90a55b0122cc54d8f"), name: 'a', value: 2 },
  { _id: ObjectId("645e8fc10a55b0122cc54d8e"), name: 'a', value: 1 }
]
shard1 [primary] test> db.test.insertOne({name: "b", value: 10})
MongoServerError: not authorized on test to execute command { insert: "test", documents: [ { name: "b", value: 10, _id: ObjectId('645e967c985a162a07ee5668') } ], ordered: true, lsid: { id: UUID("15a08a38-f8d7-41a8-86ba-a667147a2a5c") }, txnNumber: 1, $clusterTime: { clusterTime: Timestamp(1683920472, 2), signature: { hash: BinData(0, 1F33793AC2E696B4FAD2E3EB08C241B7B4F21D27), keyId: 7231278673536483329 } }, $db: "test" }
```
