
from confluent_kafka import Producer
import socket

conf = {'bootstrap.servers': '192.168.50.117:9092',
        'security.protocol': 'PLAINTEXT',
        'sasl.mechanism': 'PLAIN',
        'sasl.username': 'admin',
        'sasl.password': 'adamin',
        'client.id': socket.gethostname()}

producer = Producer(conf)


def acked(err, msg):
    if err is not None:
        print("Failed to deliver message: %s: %s" % (str(msg), str(err)))
    else:
        print("Message produced: %s" % (str(msg)))

producer.produce("tst_topic", key="key", value="test4", callback=acked)

producer.poll(1)
