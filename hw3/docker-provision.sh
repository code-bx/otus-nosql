#!/bin/bash

# Подготовить key file для аутентификации между узлами кластера.  Файл
# монтируется docker compose в образы (получается не очень безопасно, но
# возиться с docker swarm ради secrets нет желания)
if [ ! -f ./private/keyfile ]; then
    install -d -m 700 ./private
    touch ./private/keyfile
    chmod 640 ./private/keyfile
    openssl rand -base64 756 > ./private/keyfile
    sudo chown 999:999 $PWD/private/keyfile
    sudo chmod 400 $PWD/private/keyfile
fi

sudo docker-compose up -d cfg shard1 shard2 shard3

n=1
while true; do
    echo "Init cfg replicaset (try: $n) ..."
    sudo docker exec lesson06_cfg_1 mongosh admin --quiet --eval "\
try {
    rs.status().ok
} catch (e) {
  if (e.code != 13) {
    rs.initiate({
      _id : 'cfg',
      configsvr: true,
      members : [
        {'_id' : 0, host : 'lesson06_cfg_1', priority: 3},
        {'_id' : 1, host : 'lesson06_cfg_2'},
        {'_id' : 2, host : 'lesson06_cfg_3'}
        ]
    })
  }
}"
    if [ $? -eq 0 ]; then
        break;
    else
        sleep 1
        n=$(( $n + 1 ))
    fi
done

for rs in shard{1,2,3}; do
    n=1
    while true; do
        echo "Init ${rs} replicaset (try: $n) ..."
        sudo docker exec lesson06_${rs}_1 mongosh admin --quiet --eval "\
try {
    rs.status().ok
} catch (e) {
  if (e.code != 13) {
    rs.initiate({
      _id : '${rs}',
      members : [
        {'_id' : 0, host : 'lesson06_${rs}_1', priority: 3},
        {'_id' : 1, host : 'lesson06_${rs}_2'},
        {'_id' : 2, host : 'lesson06_${rs}_3'}
        ]
    })
  }
}"
        if [ $? -eq 0 ]; then
            break;
        else
            sleep 1
            n=$(( $n + 1 ))
        fi
    done
done

sudo docker-compose up -d mongos

n=1
while true; do
    echo "Waiting for mongos (try: $n) ..."
    sudo docker exec lesson06_mongos_1 mongosh --quiet \
         --eval 'db.runCommand("ping").ok'
    if [ $? -eq 0 ]; then
        break;
    else
        sleep 1
        n=$(( $n + 1 ))
    fi
done

for i in {1,2,3}; do
    echo "Adding shard${i} ..."
    sudo docker exec lesson06_mongos_1 mongosh --quiet \
         --eval "sh.addShard('shard${i}/lesson06_shard${i}_1:27017,lesson06_shard${i}_2:27017,lesson06_shard${i}_3:27017')"
done

echo "Adding root user ..."
sudo docker exec lesson06_mongos_1 mongosh admin --quiet \
     --eval "\
db.createUser({user: 'root', pwd: 'otus_r00t', roles: [ 'root' ]})
"

echo "Testing root user and cluster status ..."
sudo docker exec lesson06_mongos_1 mongosh \
     -u root -p otus_r00t --authenticationDatabase admin \
     --eval "sh.status()"
