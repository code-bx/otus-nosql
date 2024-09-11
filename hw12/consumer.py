from confluent_kafka import Consumer

conf = {'bootstrap.servers': '192.168.50.117:9092',
        'security.protocol': 'PLAINTEXT',
        'sasl.mechanism': 'PLAIN',
        'sasl.username': 'admin',
        'sasl.password': 'admin',
        'group.id': 'my_app',
        'auto.offset.reset': 'smallest'}

consumer = Consumer(conf)

consumer.subscribe(['tst_topic'])

try:
    while True:
        msg = consumer.poll(timeout=1.0)  
        if msg is None:                   
            continue
        if msg.error():                   
            raise KafkaException(msg.error())
        else:
            print(f"Received message: {msg.value().decode('utf-8')}")
except KeyboardInterrupt:
    pass
finally:
    consumer.close() 