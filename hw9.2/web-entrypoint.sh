#!/bin/bash

set -o nounset
set -o errexit

mkdir -p /etc/consul.d/data

echo '{
  "service": {
    "id": "web",
    "name": "web",
    "tags": [ "nginx" ],
    "port": 80,
    "enable_tag_override": false,
    "check": {
      "id": "web_up",
      "name": "nginx healthcheck",
      "args": ["curl", "localhost"],
      "interval": "10s",
      "timeout": "2s"
    }
  }
}' > /etc/consul.d/web.json

cat - >/etc/consul.d/agent.json <<EOF
{
    "node_name": "nginx-$(hostname)",
    "data_dir": "/etc/consul.d/data",
    "retry_join":[
      "cserv1",
      "cserv2",
      "cserv3"
     ],
    "ports":{
      "dns": 53
    },
    "recursors": [
      "127.0.0.11"
    ],
    "enable_local_script_checks": true
}
EOF

consul agent -config-dir=/etc/consul.d &
CONSUL_PID=$!

echo "search service.consul
nameserver 127.0.0.1
" > /etc/resolv.conf

echo "<html><body><p>Web node $(hostname)</p></body></html>" \
     > /var/www/html/index.nginx-debian.html

nginx -g 'daemon off;' &
NGINX_PID=$!


_term() {
  echo "Caught SIGTERM signal!"
  kill -TERM "$NGINX_PID" 2>/dev/null
  kill -TERM "$CONSUL_PID" 2>/dev/null
}
trap _term SIGTERM

wait -n

exit $?
