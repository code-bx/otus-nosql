Neo4j часть1, задание 1
=======================

## Задание

Воспользоваться моделью, данными и командами из лекции и реализовать
аналог в любой выбранной БД (реляционной или нет - на выбор). Сравнить
команды.

Написать, что удобнее было сделать в выбранной БД, а что в Neo4j и
привести примеры.


## Создание схемы

В neo4j модель создавать не надо, в postgresql приходится создавать
схему, хоть какую-нибудь, даже самую кривую. Индексы не продумывал, при
количестве записей аж целых 10, оно того не стоит.

```sql
create database otus_20_1;
\c otus20_1

create table movie (
    id serial primary key,
    title text,
    year smallint
);

create table people (
    id serial primary key,
    name text unique,
    occupation text,
    born smallint
);

create table movie2people (
    movie_id int null,
    person_id int null,
    role text,
    constraint fk_movie foreign key (movie_id) references movie(id),
    constraint fk_people foreign key (person_id) references people(id)
);
```


## 1. получить все сущности из БД

Neo4j

```
match (n) return n
```

postgresql

```sql
select * from movie;
select * from people;
```

В SQL надо отдельно обращаться к каждой таблице. Синтакцис получается
более громоздким.


## 2. Удалить все сущности в бд

neo4j

```
match (n) detach delete n
```

postgresql

```sql
delete from movie2people;
delete from movie;
delete from people;
```

Аналогично, в SQL надо работать с каждой таблицей раздельно.


## 3. создание ноды

neo4j

```
create (:Director {name:'Joel Coen'})
create (:Movie {title:'Blood Simple', year:1983})
```

postgresql

```sql
insert into people (name, occupation) values ('Joel Coen', 'Director');
insert into movie (title, year) values ('Blood Simple', 1983);
```

Отличия минимальные.


## 4. создание связи между существующими нодами, joel и blood - переменные

neo4j

```
match (joel:Director {name:'Joel Coen'})
match (blood:Movie {title:'Blood Simple'})
create (joel) -[:CREATED]-> (blood)
```

postgresql

```sql
insert into movie2people
select m.id, p.id, 'CREATED'
  from people p, movie m
 where p.name = 'Joel Coen'
   and p.occupation = 'Director'
   and m.title = 'Blood Simple';
```

SQL синтасис читать и понимать сложнее.


## 5. создание новой ноды и связи с существующей нодой

neo4j

```
match (blood:Movie {title:'Blood Simple'})
create (:Actor {name: 'Frances McDormand'}) -[:PLAYED_IN]-> (blood)
```

postgresql

```sql
insert into people (name, occupation) values ('Frances McDormand', 'Actor');
insert into movie2people
select m.id, p.id, 'PLAYED_IN'
  from people p, movie m
 where p.name = 'Frances McDormand'
   and p.occupation = 'Actor'
   and m.title = 'Blood Simple';
```

SQL получается более длинным, что, в общем-то, ожидаемо.


## 6. удаляем всё из базы

см. п.2

## 7. создание сразу нескольких нод и связей

neo4j

```
create (:Director {name:'Joel Coen'}) -[:CREATED]-> (:Movie {title:'Blood Simple', year:1983}) <-[:PLAYED_IN]- (:Actor {name: 'Frances McDormand'})
```

postgresql

```sql
insert into people (name, occupation) values ('Frances McDormand', 'Actor');
insert into movie2people
select m.id, p.id, 'PLAYED_IN'
  from people p, movie m
 where p.name = 'Frances McDormand'
   and p.occupation = 'Actor'
   and m.title = 'Blood Simple';
insert into movie2people
select m.id, p.id, 'CREATED'
  from people p, movie m
 where p.name = 'Joel Coen'
   and p.occupation = 'Director'
   and m.title = 'Blood Simple';
insert into people (name, occupation) values ('Joel Coen', 'Director');
insert into movie (title, year) values ('Blood Simple', 1983);
insert into movie2people
select m.id, p.id, 'PLAYED_IN'
  from people p, movie m
 where p.name = 'Frances McDormand'
   and p.occupation = 'Actor'
   and m.title = 'Blood Simple';
```

В SQL не поддерживается. Надо делать отдельными командами


## 8. пробуем создать ноду 2 раза

neo4j

```
create (:Director {name:'Martin Scorsese'})
create (:Director {name:'Martin Scorsese'})
```

postgresql

```sql
insert into people (name, occupation) values ('Martin Scorsese', 'Director');
insert into people (name, occupation) values ('Martin Scorsese', 'Director');
```

Возможность создания дублирующихся записей определяется наличием
ограничений целостности, как в RDBMS, так и в neo4j. Если ограничений
нет, записи будут созданы.


## 9. создать ноду, если не существует

neo4j

```
merge (:Director {name: 'Ethan Coen'})
merge (:Director {name: 'Ethan Coen'})
```

postgresql

```sql
insert into people (name, occupation)
with src as (select 'Ethan Coen' as name, 'Director' as occupation)
select *
  from src
 where not exists (select 1 from people dst where src.name = dst.name
                                              and src.occupation = dst.occupation)
```

SQL вариант сильно длиннее


## 10. создать связь, если не существует

neo4j

```
match (n:Director {name: 'Ethan Coen'})
match (m:Movie {title: 'Blood Simple'})
merge (n) -[:CREATED]-> (m)
```

postgresql

```sql
insert into movie2people
with src as (
 select m.id as movie_id, p.id as person_id, 'CREATED' as role
  from people p, movie m
 where p.name = 'Ethan Coen'
   and p.occupation = 'Director'
   and m.title = 'Blood Simple'
)
select *
  from src
 where not exists (select 1 from movie2people dst
                    where src.movie_id = dst.movie_id
                      and src.person_id = dst.person_id
                      and src.role = dst.role)
```

Аналогично, синтксис SQL сильно проигрывает Cypher на специфичных
задачах работы с графами. Ожидаемо.


## 11. добавить свойство к ноде

neo4j

```
match (n:Director {name:'Ethan Coen'})
SET n.born = 1957
```

postgresql

```sql
update people
   set born = 1957
 where name = 'Ethan Coen'
   and occupation = 'Director';
```


## 12 добавить свойство к связи

neo4j

```
match (:Actor {name:'Frances McDormand'}) -[r:PLAYED_IN]-> (:Movie {title: 'Blood Simple'})
set r.character = 'Abby'
```

postgresql

```sql
update movie2people d
  set character = 'Abby'
 where (d.movie_id, d.person_id, d.role) in
       (
        select m.id, p.id, 'PLAYED_IN'
          from movie m, people p
         where m.title = 'Blood Simple'
           and p.name = 'Frances McDormand'
           and p.occupation = 'Actor'
       )
```

Добавление несуществующего свойства в RDBMS требует изменения модели.


## 13 удалить ноду

neo4j

```
match (martin:Director {name:'Martin Scorsese'}) delete martin
```

postgresql

```sql
delete from people
 where name = 'Martin Scorsese'
   and occupation = 'Director'
```

## 14 удалить свойство с помощью REMOVE

neo4j

```
match (n:Director {name:'Ethan Coen'})
REMOVE n.born
```

postgresql

Нельзя удалить свойство из отдельной записи, только изменить структуру
таблицы целоком. Хотя, если переделать схему и запихать свойства в
отдельную таблицу (node_id, key, value). Работать будет, но запросы
превратятся в развесистые кусты соединений.


## 15 удалить свойство с помощью SET null

neo4j

```
match (n:Director {name:'Ethan Coen'})
SET n.born = null
```

postgresql

```sql
update people
   set born = null
 where name = 'Ethan Coen'
   and occupation = 'Director';
```


## 16 удалить все ребра для ноды

neo4j

```
match (n:Director {name:'Ethan Coen'}) -[r]- () delete r
```

postgresl

```sql
delete from movie2people
 where (person_id) in (select id from people
                        where name = 'Ethan Coen'
                          and occupation = 'Director'
                      )
```

Еще повезло, что таблица для связей в RDBMS всего одна. Иначе бы
пришлось писать несолько запросов, по одному на таблицую.


## 17 найти ноду

neo4j

```
match (joel:Director {name: 'Joel Coen'})
```

postgresql

```sql
select *
  from people
 where name = 'Joel Coen'
   and occupation = 'Director'
```

Аналогично. В данном случае тип узла вел к одной таблице, если бы не
повезло, пришлось бы обходить несколько таблиц и потребовались бы
внешние метаданные для выяснения, какие таблицы содержат узлы, а какие
что-то другое.


## 18 найти ноду имеющую связь с другой нодой с указание метки Label нод

neo4j

```
match (d:Director) -[r]- (m:Movie) return d, r, m
```

postgresql

```sql
select name, role, title
  from movie2people r
       inner join people p on (r.person_id = p.id)
       inner join movie m on (r.movie_id = m.id)
 where p.occupation = 'Director'
```

Общей формы запроса в SQL нет, но под конкретную схему можно
вывернуться.


## 19 найти любые ноды, имеющие связь с другими нодами

…

postgresql

```sql
select distinct label from (
select name as label from people inner join movie2people on (id = person_id)
union all
select title as label from movie inner join movie2people on (id = movie_id)
)
```

Общей формы запроса в SQL нет. Запрос придется переписывать под каждую
конкретную схему. Зато он не вывалится по out of memory. Хотя, это как
постараться distinct может и упасть на очень больших объемах, но
потребление памяти будет линейно расти от количества узлов. Никаких
полиномов высоких степеней (хотя, O(N^2) может и выйдет) и тем более
экспонент.


## 20 почистим все

neo4j

```
match (n) detach delete n
```

postgresql

см. п.2

## 21 создадим данные

neo4j

```
create (:Director {name:'Joel Coen'}) -[:CREATED]-> (blood:Movie {title:'Blood Simple', year:1983}) <-[:PLAYED_IN {character: 'Abby'}]- (:Actor {name: 'Frances McDormand'})
create (:Director {name:'Ethan Coen', born:1957}) -[:CREATED]-> (blood)
```

postgresql

```sql
insert into movie (title, year) values ('Blood Simple', 1983);
insert into people (name, occupation) values ('Joel Coen', 'Director');
insert into people (name, occupation, born) values ('Ethan Coen', 'Director', 1957);
insert into people (name, occupation) values ('Frances McDormand', 'Actor');
insert into movie2people (movie_id, person_id, role, character)
select m.id, p.id, 'PLAYED_IN', 'Abby'
  from people p, movie m
 where p.name = 'Frances McDormand'
   and p.occupation = 'Actor'
   and m.title = 'Blood Simple';
insert into movie2people
select m.id, p.id, 'CREATED'
  from people p, movie m
 where p.name = 'Joel Coen'
   and p.occupation = 'Director'
   and m.title = 'Blood Simple';
insert into movie2people
select m.id, p.id, 'CREATED'
  from people p, movie m
 where p.name = 'Ethan Coen'
   and p.occupation = 'Director'
   and m.title = 'Blood Simple';
```

## 22 создадим еще больше данных

neo4j

```
match (frances:Actor {name:'Frances McDormand'})
match (leo:Actor {name:'Leonardo DiCaprio'})
create (:Director {name:'Martin McDonagh'}) -[:CREATED]-> (billboards:Movie {title:'Three Billboards Outside Ebbing, Missouri'})
create (frances) -[:PLAYED_IN]-> (billboards)
create (venom:Movie {title:'Venom'}) <-[:PLAYED_IN]- (woodie:Actor {name:'Woody Harrelson'}) -[:PLAYED_IN]-> (billboards)
create (venom) <-[:PLAYED_IN]- (tom:Actor {name:'Tom Hardy'})
create (leo) -[:PLAYED_IN]-> (inception:Movie {name:'Inception'}) <-[:PLAYED_IN]- (tom)
create (marion:Actor {name:'Marion Cotillard'}) -[:PLAYED_IN]-> (inception)
create (marion) -[:PLAYED_IN]-> (:Movie {title: 'The Dark Knight Rises'}) <-[:PLAYED_IN]- (tom)
create (nolan:Director {name:'Christopher Nolan'}) -[:CREATED]-> (batman)
create (nolan) -[:CREATED]-> (inception)
create (:Director {name:'Ruben Fleischer'}) -[:CREATED]-> (venom)
```

Исходный запрос в примере был с ошибками и ничего не добавлял. Пришлось вносить правки.

```
match (frances:Actor {name:'Frances McDormand'})
create (leo:Actor {name:'Leonardo DiCaprio'})
create (:Director {name:'Martin McDonagh'}) -[:CREATED]-> (billboards:Movie {title:'Three Billboards Outside Ebbing, Missouri'})
create (frances) -[:PLAYED_IN]-> (billboards)
create (venom:Movie {title:'Venom'}) <-[:PLAYED_IN]- (woodie:Actor {name:'Woody Harrelson'}) -[:PLAYED_IN]-> (billboards)
create (venom) <-[:PLAYED_IN]- (tom:Actor {name:'Tom Hardy'})
create (leo) -[:PLAYED_IN]-> (inception:Movie {title:'Inception'}) <-[:PLAYED_IN]- (tom)
create (marion:Actor {name:'Marion Cotillard'}) -[:PLAYED_IN]-> (inception)
create (marion) -[:PLAYED_IN]-> (batman:Movie {title: 'The Dark Knight Rises'}) <-[:PLAYED_IN]- (tom)
create (nolan:Director {name:'Christopher Nolan'}) -[:CREATED]-> (batman)
create (nolan) -[:CREATED]-> (inception)
create (:Director {name:'Ruben Fleischer'}) -[:CREATED]-> (venom)
```

```sql
insert into movie (title) values ('Three Billboards Outside Ebbing, Missouri');
insert into movie (title) values ('Venom');
insert into movie (title) values ('Inception');
insert into movie (title) values ('The Dark Knight Rises');
insert into people (name, occupation) values ('Martin McDonagh', 'Director');
insert into people (name, occupation) values ('Christopher Nolan', 'Director');
insert into people (name, occupation) values ('Ruben Fleischer', 'Director');
insert into people (name, occupation) values ('Leonardo DiCaprio', 'Actor');
insert into people (name, occupation) values ('Woody Harrelson', 'Actor');
insert into people (name, occupation) values ('Tom Hardy', 'Actor');
insert into people (name, occupation) values ('Marion Cotillard', 'Actor');
insert into movie2people (movie_id, person_id, role)
select m.id, p.id, 'CREATED'
  from people p, movie m
 where p.name = 'Martin McDonagh'
   and p.occupation = 'Director'
   and m.title = 'Three Billboards Outside Ebbing, Missouri';
insert into movie2people (movie_id, person_id, role)
select m.id, p.id, 'CREATED'
  from people p, movie m
 where p.name = 'Christopher Nolan'
   and p.occupation = 'Director'
   and m.title = 'The Dark Knight Rises';
insert into movie2people (movie_id, person_id, role)
select m.id, p.id, 'CREATED'
  from people p, movie m
 where p.name = 'Christopher Nolan'
   and p.occupation = 'Director'
   and m.title = 'Inception';
insert into movie2people (movie_id, person_id, role)
select m.id, p.id, 'CREATED'
  from people p, movie m
 where p.name = 'Ruben Fleischer'
   and p.occupation = 'Director'
   and m.title = 'Venom';
insert into movie2people (movie_id, person_id, role)
select m.id, p.id, 'PLAYED_IN'
  from people p, movie m
 where p.name = 'Frances McDormand'
   and p.occupation = 'Actor'
   and m.title = 'Three Billboards Outside Ebbing, Missouri';
insert into movie2people (movie_id, person_id, role)
select m.id, p.id, 'PLAYED_IN'
  from people p, movie m
 where p.name = 'Woody Harrelson'
   and p.occupation = 'Actor'
   and m.title = 'Venom';
insert into movie2people (movie_id, person_id, role)
select m.id, p.id, 'PLAYED_IN'
  from people p, movie m
 where p.name = 'Woody Harrelson'
   and p.occupation = 'Actor'
   and m.title = 'Three Billboards Outside Ebbing, Missouri';
insert into movie2people (movie_id, person_id, role)
select m.id, p.id, 'PLAYED_IN'
  from people p, movie m
 where p.name = 'Tom Hardy'
   and p.occupation = 'Actor'
   and m.title = 'Venom';
insert into movie2people (movie_id, person_id, role)
select m.id, p.id, 'PLAYED_IN'
  from people p, movie m
 where p.name = 'Leonardo DiCaprio'
   and p.occupation = 'Actor'
   and m.title = 'Inception';
insert into movie2people (movie_id, person_id, role)
select m.id, p.id, 'PLAYED_IN'
  from people p, movie m
 where p.name = 'Tom Hardy'
   and p.occupation = 'Actor'
   and m.title = 'Inception';
insert into movie2people (movie_id, person_id, role)
select m.id, p.id, 'PLAYED_IN'
  from people p, movie m
 where p.name = 'Marion Cotillard'
   and p.occupation = 'Actor'
   and m.title = 'Inception';
insert into movie2people (movie_id, person_id, role)
select m.id, p.id, 'PLAYED_IN'
  from people p, movie m
 where p.name = 'Marion Cotillard'
   and p.occupation = 'Actor'
   and m.title = 'The Dark Knight Rises';
insert into movie2people (movie_id, person_id, role)
select m.id, p.id, 'PLAYED_IN'
  from people p, movie m
 where p.name = 'Tom Hardy'
   and p.occupation = 'Actor'
   and m.title = 'The Dark Knight Rises';
```


## 23 найти ноду имеющую связь с другой нодой с указание метки Label нод

neo4j

```
match (venom:Movie {title:'Venom'}) -[*1..3]- (d:Director) return d
```

postgresql

```sql
with recursive
  edge as (
    select movie_id as node_id, 'Movie' node_type
         , title
         , '<'||role as role
         , person_id as link_node_id, occupation as link_node_type
         , name
      from movie2people r
           inner join people p on (r.person_id = p.id)
           inner join movie m on (r.movie_id = m.id)
     where 1=1
    union all
    select person_id as link_node_id, occupation as link_node_type
         , name
         , role||'>' as role
         , movie_id as node_id, 'Movie' node_type
         , title
      from movie2people r
           inner join people p on (r.person_id = p.id)
           inner join movie m on (r.movie_id = m.id)
     where 1=1
  )
, rcte as (
    select id as node_id, 'Movie' node_type
         , 0 as distance
         , ARRAY[(id,'Movie'::text)] as path
         , false as cycle
         , null::text as name
         , title
      from movie
     where title = 'Venom'
     union
    select link_node_id as node_id, link_node_type as node_type
         , rcte.distance + 1 as distance
         , (link_node_id, link_node_type) || rcte.path as path
         , (link_node_id, link_node_type) = ANY(rcte.path) as cycle
         , edge.name
         , edge.title
      from edge
           inner join rcte using (node_id, node_type)
     where not cycle
  )
select distinct name
  from rcte
 where 1=1
   and distance <= 3
   and node_type = 'Director';
```

SQL вариант запроса, мягко выражаясь, сильно забористее.


## Выводы

Использование негодного инструмента для задачи всегда большой головняк.

Голый SQL и RDBMS для работы с графами — это негодный инструмент.
