ДЗ №12 по курсу NoSQL.

Задание:

Запустите Kafka (можно в docker)
Отправьте несколько сообщений используя утилиту kafka-producer
Прочитайте их, используя графический интерфейс или утилиту kafka-consumer
Отправьте и прочитайте сообщения программно - выберите знакомый язык программирования (C#, Java, Python или любой другой, для которого есть библиотека для работы с Kafka), отправьте и прочитайте несколько сообщений
Для пунктов 2 и 3 сделайте скриншоты отправки и получения сообщений.
Для пункта 4 приложите ссылку на репозитарий на гитхабе с исходным кодом.

Решение:

Kafka и Zookeeper развернул в docker.
Подключился в контейнер и из командной строки запустил команду создания топика:
kafka-topics --bootstrap-server localhost:9092 --topic tst_topic --create --partitions 1 --replication-factor 1

Подключился в консоль producer и отправил сообщения:
kafka-console-producer --bootstrap-server localhost:9092 --topic tst_topic

В новом окне подключился к контейнеру, открыл консоль consumer и принял сообщения:
kafka-console-consumer --bootstrap-server localhost:9092 --topic tst_topic --from-beginning


На Python создал простой скрипт producer и consumer. Отправил и получил сообщения. Скрипты прикладываю.