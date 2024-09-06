Базовые возможности mongodb
===========================

## Установка MongoDB

Ручная установка MongoDB 6.0.x в Debian 11 (vagrant debian/bullseye64)
по документации
```bash
sudo wget https://pgp.mongodb.com/server-6.0.pub \
       -O /etc/apt/trusted.gpg.d/mongodb-server-6.0.gpg && \
echo "deb http://repo.mongodb.org/apt/debian bullseye/mongodb-org/6.0 main" \
   | sudo tee /etc/apt/sources.list.d/mongodb-org-6.0.list && \
sudo apt update && \
sudo apt install -y mongodb-org
```

Установилась версия 6.0.5
```console
vagrant@otus-lesson03:~$ dpkg -l 'mongo*' | grep -v ^u
Desired=Unknown/Install/Remove/Purge/Hold
| Status=Not/Inst/Conf-files/Unpacked/halF-conf/Half-inst/trig-aWait/Trig-pend
|/ Err?=(none)/Reinst-required (Status,Err: uppercase=bad)
||/ Name                                             Version      Architecture
+++-================================================-============-============-
ii  mongodb-database-tools                           100.7.0      amd64
ii  mongodb-mongosh                                  1.8.0        amd64
ii  mongodb-org                                      6.0.5        amd64
ii  mongodb-org-database                             6.0.5        amd64
ii  mongodb-org-database-tools-extra                 6.0.5        amd64
ii  mongodb-org-mongos                               6.0.5        amd64
ii  mongodb-org-server                               6.0.5        amd64
ii  mongodb-org-shell                                6.0.5        amd64
ii  mongodb-org-tools                                6.0.5        amd64
```

Настройка сервиса
```console
vagrant@otus-lesson03:~$ sudo systemctl start mongod.service
vagrant@otus-lesson03:~$ sudo systemctl enable mongod.service
Created symlink /etc/systemd/system/multi-user.target.wants/mongod.service → /lib/systemd/system/mongod.service.
vagrant@otus-lesson03:~$ systemctl status mongod.service
● mongod.service - MongoDB Database Server
     Loaded: loaded (/lib/systemd/system/mongod.service; disabled; vendor preset: enabled)
     Active: active (running) since ...
       Docs: https://docs.mongodb.org/manual
   Main PID: 2538 (mongod)
     Memory: 129.5M
        CPU: 1.321s
     CGroup: /system.slice/mongod.service
             └─2538 /usr/bin/mongod --config /etc/mongod.conf
```

Создание пользователя с паролем (
```console
test> disableTelemetry()
Telemetry is now disabled.
test> use admin
admin> db.createUser(
      {
        user: "root",
        pwd: passwordPrompt(),
        roles: [
          { role: "userAdminAnyDatabase", db: "admin" },
          { role: "readWriteAnyDatabase", db: "admin" }
        ]
      }
    )
Enter password
{ ok: 1 }
```

Для включения внешнего доступа `/etc/mongod.conf` добавить `net.bindIpAll: true` и `security.authorization: enabled`


## Загрузка данных

[The MongoDB Atlas Sample Datasets](https://www.mongodb.com/developer/products/atlas/atlas-sample-datasets/)

Чтобы не возиться с полным набором забрал sample_mllix с [GitHub](https://github.com/mcampo2/mongodb-sample-databases)
```bash
(
user=root
read -sp "$user password: " pass; echo
for file in comments.json movies.json sessions.json theaters.json users.json; do
  base_url=https://github.com/mcampo2/mongodb-sample-databases/raw/master/sample_mflix
  [ -f $file ] || wget $base_url/$file
  mongoimport --drop --db otus --collection "$(basename $file .json)" \
    --type=json --file $file \
    --authenticationDatabase "admin" -u $user -p "$pass"
done
)
```


## Запросы к данным

Подключение к БД
```bash
mongosh --authenticationDatabase "admin" -u root otus
```

Поиск данных
```
otus> show collections
comments
movies
sessions
theaters
users

otus> db.movies.countDocuments()
23539

otus> db.movies.find({title: {$regex:"home", $options:"i"}, "imdb.rating": {$gt: 8}}, {title:1,genres:1,"imdb.rating":1,_id:0})
[
  {
    genres: [ 'Drama', 'Family' ],
    title: "Where is the Friend's Home?",
    imdb: { rating: 8.1 }
  },
  {
    genres: [ 'Documentary' ],
    title: 'Alive Day Memories: Home from Iraq',
    imdb: { rating: 8.1 }
  },
  {
    genres: [ 'Documentary', 'Drama', 'Family' ],
    title: 'Home',
    imdb: { rating: 8.6 }
  },
  {
    genres: [ 'Documentary' ],
    title: 'Homeland (Iraq Year Zero)',
    imdb: { rating: 8.8 }
  }
]
```

Обновление записей
```console
otus> db.users.find({email: "blake_sellers@fakegmail.com"})
[
  {
    _id: ObjectId("59b99dfccfa9a34dcd788650"),
    name: 'Blake Sellers',
    email: 'blake_sellers@fakegmail.com',
    password: '$2b$12$g2u20yqqpzbNipA6lfIoBO3Cs9jM7jsWBhDheF1OsthHpLfEcD2Gm'
  }
]
db.users.updateOne({_id: ObjectId("59b99dfccfa9a34dcd788650")}, {$set: {locked: 1}})
{
  acknowledged: true,
  insertedId: null,
  matchedCount: 1,
  modifiedCount: 1,
  upsertedCount: 0
}
otus> db.users.find({email: "blake_sellers@fakegmail.com"})
[
  {
    _id: ObjectId("59b99dfccfa9a34dcd788650"),
    name: 'Blake Sellers',
    email: 'blake_sellers@fakegmail.com',
    password: '$2b$12$g2u20yqqpzbNipA6lfIoBO3Cs9jM7jsWBhDheF1OsthHpLfEcD2Gm',
    locked: 1
  }
]
```

Удаление записей
``` console
otus> db.comments.aggregate([{$group: {_id: "$name", count: {$sum: 1}}}])
[
  { _id: 'Elizabeth Delacruz', count: 2 },
  { _id: 'Kelsey Smith', count: 271 },
  { _id: 'Bradley Brooks', count: 296 },
  { _id: 'Jordan Medina', count: 253 },
  { _id: 'Jorah Mormont', count: 273 },
  { _id: 'tlztq1ul4', count: 1 },
  { _id: 'Deborah Perez', count: 3 },
  { _id: 'Brienne of Tarth', count: 302 },
  { _id: 'Nicholas Webster', count: 259 },
  { _id: 'ubjfpg48b', count: 1 },
  { _id: 'Victor Patel', count: 239 },
  { _id: 'gwy1uyx6i', count: 1 },
  { _id: 'Tormund Giantsbane', count: 284 },
  { _id: 'vzgg2p0ff', count: 1 },
  { _id: 'Desiree Pierce', count: 287 },
  { _id: '9lk9r112i', count: 1 },
  { _id: 'j9g70tily', count: 1 },
  { _id: 'Jojen Reed', count: 258 },
  { _id: 'Tommen Baratheon', count: 291 },
  { _id: 'gaixjzunk', count: 1 }
]
Type "it" for more
otus> db.comments.deleteMany({name: "Jojen Reed"})
{ acknowledged: true, deletedCount: 258 }
otus> db.users.find({name: "Jojen Reed"})
[
  {
    _id: ObjectId("59b99dddcfa9a34dcd788603"),
    name: 'Jojen Reed',
    email: 'thomas_brodie-sangster@gameofthron.es',
    password: '$2b$12$ZAJ8OFWUFNdxhc0xyTd42evQJfL7FnEdk3koHwYtHpDqsrZI61XP.'
  }
]
otus> db.users.deleteOne({name: "Jojen Reed"})
{ acknowledged: true, deletedCount: 1 }
```
