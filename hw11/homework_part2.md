Neo4j моделирование туристических маршрутов
===========================================

В географии не силен. Все маршруты вымышленные, а названия случайные.


Загрузка данных
======================

1. Взять 4-5 популярных туроператора.
2. Каждый туроператор должен быть представлен в виде ноды neo4j
3. Взять 10-15 направлений, в которые данные операторы предосавляют
   путевки.
4. Представить направления в виде связки нод: страна - конкретное место
5. Взять ближайшие к туриситческим локацимя города, в которых есть
   аэропорты или вокзалы и представить их в виде нод
6. Представить маршруты между городми в виде связей. Каждый маршрут
   должен быть охарактеризован видом транспорта, который позволяет
   переместиться между точками.

Данные

```cypher
// Travel Agencies
create (a1:TravelAgency {name:"Tour Shop"})
create (a2:TravelAgency {name:"Smart Tour"})
create (a3:TravelAgency {name:"Best Tour"})
create (a4:TravelAgency {name:"Tour Global"})
create (a5:TravelAgency {name:"Fun Tour"})

// Countries
create (n:Country {name: "Niave"})
create (e:Country {name: "Egha Lands"})
create (s:Country {name: "Stanbena"})
create (w:Country {name: "Walesbo"})

// Destinations
create (  d1:Destination {name: "Edgepond"      }) -[:LOCATED_IN]-> (n)
create (  d2:Destination {name: "Greenhill"     }) -[:LOCATED_IN]-> (n)
create ( d2a:Destination {name: "Morcastle"     }) -[:LOCATED_IN]-> (n)
create (  d3:Destination {name: "Summermill"    }) -[:LOCATED_IN]-> (n)
create (  d4:Destination {name: "Valwick"       }) -[:LOCATED_IN]-> (n)
create (  d5:Destination {name: "Jandell"       }) -[:LOCATED_IN]-> (n)
create (  d6:Destination {name: "Vertmere"      }) -[:LOCATED_IN]-> (e)
create (  d7:Destination {name: "Glassspring"   }) -[:LOCATED_IN]-> (e)
create (  d8:Destination {name: "Violetbarrow"  }) -[:LOCATED_IN]-> (e)
create (  d9:Destination {name: "Glasscastle"   }) -[:LOCATED_IN]-> (s)
create ( d10:Destination {name: "Byville"       }) -[:LOCATED_IN]-> (s)
create (d10a:Destination {name: "Courtpond"     }) -[:LOCATED_IN]-> (s)
create ( d11:Destination {name: "Swynton"       }) -[:LOCATED_IN]-> (s)
create ( d12:Destination {name: "Oldmead"       }) -[:LOCATED_IN]-> (s)
create ( d13:Destination {name: "Fieldbarrow"   }) -[:LOCATED_IN]-> (w)
create ( d14:Destination {name: "Beachland"     }) -[:LOCATED_IN]-> (w)
create ( d15:Destination {name: "Moorwald"      }) -[:LOCATED_IN]-> (w)

// Cities
create (n1:City {name:"Srafield"               }) -[:LOCATED_IN]-> (n)
create (n2:City {name:"Zlaibus"                }) -[:LOCATED_IN]-> (n)
create (n3:City {name:"Tenbury Wells"          }) -[:LOCATED_IN]-> (n)
create (n4:City {name:"Andover"                }) -[:LOCATED_IN]-> (n)
create (n5:City {name:"Dawson Creek"           }) -[:LOCATED_IN]-> (n)
create (e1:City {name:"Watkins Glen"           }) -[:LOCATED_IN]-> (e)
create (e2:City {name:"Plainview"              }) -[:LOCATED_IN]-> (e)
create (e3:City {name:"Redding"                }) -[:LOCATED_IN]-> (e)
create (s1:City {name:"Elstree and Borehamwood"}) -[:LOCATED_IN]-> (s)
create (s2:City {name:"Balranald"              }) -[:LOCATED_IN]-> (s)
create (s3:City {name:"Vincennes"              }) -[:LOCATED_IN]-> (s)
create (s4:City {name:"Ashburton"              }) -[:LOCATED_IN]-> (s)
create (w1:City {name:"Johnstown"              }) -[:LOCATED_IN]-> (w)
create (w2:City {name:"Oskaloosa"              }) -[:LOCATED_IN]-> (w)
create (w3:City {name:"Tewksbury"              }) -[:LOCATED_IN]-> (w)
create (w4:City {name:"Baymont Ridge"          }) -[:LOCATED_IN]-> (w)


// Tour sales
create (a1) -[:SELL]-> (d1)
create (a1) -[:SELL]-> (d2a)
create (a1) -[:SELL]-> (d3)
create (a1) -[:SELL]-> (d5)
create (a1) -[:SELL]-> (d9)
create (a1) -[:SELL]-> (d10)
create (a1) -[:SELL]-> (d12)
create (a1) -[:SELL]-> (d13)

create (a2) -[:SELL]-> (d2)
create (a2) -[:SELL]-> (d2a)
create (a2) -[:SELL]-> (d4)
create (a2) -[:SELL]-> (d9)
create (a2) -[:SELL]-> (d10a)
create (a2) -[:SELL]-> (d11)
create (a2) -[:SELL]-> (d13)
create (a2) -[:SELL]-> (d14)
create (a2) -[:SELL]-> (d15)

create (a3) -[:SELL]-> (d1)
create (a3) -[:SELL]-> (d2)
create (a3) -[:SELL]-> (d2a)
create (a3) -[:SELL]-> (d3)
create (a3) -[:SELL]-> (d5)
create (a3) -[:SELL]-> (d6)
create (a3) -[:SELL]-> (d7)
create (a3) -[:SELL]-> (d8)

create (a4) -[:SELL]-> (d3)
create (a4) -[:SELL]-> (d4)
create (a4) -[:SELL]-> (d6)
create (a4) -[:SELL]-> (d7)
create (a4) -[:SELL]-> (d9)
create (a4) -[:SELL]-> (d10)
create (a4) -[:SELL]-> (d11)
create (a4) -[:SELL]-> (d12)

create (a5) -[:SELL]-> (d1)
create (a5) -[:SELL]-> (d2)
create (a5) -[:SELL]-> (d4)
create (a5) -[:SELL]-> (d8)
create (a5) -[:SELL]-> (d10a)
create (a5) -[:SELL]-> (d11)
create (a5) -[:SELL]-> (d13)
create (a5) -[:SELL]-> (d15)


// Routes
create (n1)  -[:ROUTE {kind: "land"}]-> (n3)
create (n3)  -[:ROUTE {kind: "land"}]-> (n1)

create (n1)  -[:ROUTE {kind: "land"}]-> (n4)
create (n4)  -[:ROUTE {kind: "land"}]-> (n1)

create (n3)  -[:ROUTE {kind: "land"}]-> (d2)
create (d2)  -[:ROUTE {kind: "land"}]-> (n3)

create (n3)  -[:ROUTE {kind: "land"}]-> (d4)
create (d4)  -[:ROUTE {kind: "land"}]-> (n3)

create (n4)  -[:ROUTE {kind: "land"}]-> (d3)
create (d3)  -[:ROUTE {kind: "land"}]-> (n4)

create (n4)  -[:ROUTE {kind: "land"}]-> (n5)
create (n5)  -[:ROUTE {kind: "land"}]-> (n4)

create (n5)  -[:ROUTE {kind: "air"}]-> (n2)
create (n2)  -[:ROUTE {kind: "air"}]-> (n5)

create (n5)  -[:ROUTE {kind: "air"}]-> (w2)
create (w2)  -[:ROUTE {kind: "air"}]-> (n5)

create (n5)  -[:ROUTE {kind: "air"}]-> (s1)
create (s1)  -[:ROUTE {kind: "air"}]-> (n5)

create (n2)  -[:ROUTE {kind: "land"}]-> (d2)
create (d2)  -[:ROUTE {kind: "land"}]-> (n2)

create (n2)  -[:ROUTE {kind: "land"}]-> (d2a)
create (d2a) -[:ROUTE {kind: "land"}]-> (n2)

create (n2)  -[:ROUTE {kind: "air"}]-> (e1)
create (e1)  -[:ROUTE {kind: "air"}]-> (n2)


create (e1)  -[:ROUTE {kind: "land"}]-> (d5)
create (d5)  -[:ROUTE {kind: "land"}]-> (e1)

create (e1)  -[:ROUTE {kind: "land"}]-> (d6)
create (d6)  -[:ROUTE {kind: "land"}]-> (e1)

create (e1)  -[:ROUTE {kind: "land"}]-> (e3)
create (e3)  -[:ROUTE {kind: "land"}]-> (e1)

create (e1)  -[:ROUTE {kind: "air"}]-> (e2)
create (e2)  -[:ROUTE {kind: "air"}]-> (e1)

create (e3)  -[:ROUTE {kind: "land"}]-> (d7)
create (d7)  -[:ROUTE {kind: "land"}]-> (e3)

create (d7)  -[:ROUTE {kind: "land"}]-> (d8)
create (d8)  -[:ROUTE {kind: "land"}]-> (d7)

create (d8)  -[:ROUTE {kind: "land"}]-> (e2)
create (e2)  -[:ROUTE {kind: "land"}]-> (d8)

create (e2)  -[:ROUTE {kind: "air"}]-> (s3)
create (s3)  -[:ROUTE {kind: "air"}]-> (e2)

create (e2)  -[:ROUTE {kind: "land"}]-> (s4)
create (s4)  -[:ROUTE {kind: "land"}]-> (e2)


create (s4)  -[:ROUTE {kind: "land"}]-> (s2)
create (s2)  -[:ROUTE {kind: "land"}]-> (s4)

create (d12) -[:ROUTE {kind: "land"}]-> (s3)
create (s3)  -[:ROUTE {kind: "land"}]-> (d12)

create (s3)  -[:ROUTE {kind: "land"}]-> (d11)
create (d11) -[:ROUTE {kind: "land"}]-> (s3)

create (s3)  -[:ROUTE {kind: "air"}]-> (s1)
create (s1)  -[:ROUTE {kind: "air"}]-> (s3)

create (s3)  -[:ROUTE {kind: "air"}]-> (w4)
create (w4)  -[:ROUTE {kind: "air"}]-> (s3)

create (d11) -[:ROUTE {kind: "land"}]-> (s2)
create (s2)  -[:ROUTE {kind: "land"}]-> (d11)

create (s2)  -[:ROUTE {kind: "land"}]-> (d10)
create (d10) -[:ROUTE {kind: "land"}]-> (s2)

create (d10)  -[:ROUTE {kind: "land"}]-> (d10a)
create (d10a) -[:ROUTE {kind: "land"}]-> (d10)

create (d10)  -[:ROUTE {kind: "land"}]-> (s1)
create (s1)   -[:ROUTE {kind: "land"}]-> (d10)

create (s1)   -[:ROUTE {kind: "land"}]-> (d8)
create (d8)   -[:ROUTE {kind: "land"}]-> (s1)

create (d8)   -[:ROUTE {kind: "land"}]-> (d14)
create (d14)  -[:ROUTE {kind: "land"}]-> (d8)

create (d14)  -[:ROUTE {kind: "land"}]-> (w1)
create (w1)   -[:ROUTE {kind: "land"}]-> (d14)

create (w4)   -[:ROUTE {kind: "air"}]-> (w1)
create (w1)   -[:ROUTE {kind: "air"}]-> (w4)

create (w1)   -[:ROUTE {kind: "air"}]-> (w2)
create (w2)   -[:ROUTE {kind: "air"}]-> (w1)

create (w2)   -[:ROUTE {kind: "land"}]-> (w3)
create (w3)   -[:ROUTE {kind: "land"}]-> (w2)

create (w2)   -[:ROUTE {kind: "land"}]-> (d13)
create (d13)  -[:ROUTE {kind: "land"}]-> (w2)

create (w2)   -[:ROUTE {kind: "land"}]-> (d15)
create (d15)  -[:ROUTE {kind: "land"}]-> (w3)

```

Запрос маршрутов
================

Написать запрос, который бы выводил направление (со всеми промежуточными
точками), который можно осуществить только наземным транспортом.

```cypher
match
(d:Destination {name:"Byville"}),
path = shortestPath((c) -[:ROUTE*]-> (d))
WHERE all(r IN relationships(path) WHERE r.kind = "land")
  and c.name <> 'Byville'
return path
```
