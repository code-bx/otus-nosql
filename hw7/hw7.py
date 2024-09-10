#!/usr/bin/env python
# -*- coding: utf-8 -*-

from collections import Counter
from collections import namedtuple
import json
import lzma

import pytest

from redis import Redis


result_expected = {
    b'AUDI': 2622,
    b'AZURE DYNAMICS': 7,
    b'BENTLEY': 3,
    b'BMW': 5696,
    b'CADILLAC': 103,
    b'CHEVROLET': 11251,
    b'CHRYSLER': 2139,
    b'FIAT': 803,
    b'FISKER': 14,
    b'FORD': 6743,
    b'GENESIS': 54,
    b'HONDA': 791,
    b'HYUNDAI': 2144,
    b'JAGUAR': 222,
    b'JEEP': 2328,
    b'KIA': 5252,
    b'LAND ROVER': 41,
    b'LEXUS': 64,
    b'LINCOLN': 208,
    b'LUCID': 133,
    b'MERCEDES-BENZ': 711,
    b'MINI': 728,
    b'MITSUBISHI': 710,
    b'NISSAN': 13023,
    b'POLESTAR': 648,
    b'PORSCHE': 936,
    b'RIVIAN': 1612,
    b'SMART': 276,
    b'SUBARU': 231,
    b'TESLA': 59629,
    b'TH!NK': 3,
    b'TOYOTA': 4770,
    b'VOLKSWAGEN': 3432,
    b'VOLVO': 3113,
    b'WHEEGO ELECTRIC CARS': 3,
}


keyhead = "otus16"
MAKE_IDX = 14
OtusTestData = namedtuple("OtusTestData", ["cols", "rows"])


@pytest.fixture(scope="module")
def data():
    d = json.load(lzma.open("electric-vehicle-population-data.json.xz", "r"))
    col_names = [c["name"] for c in d["meta"]["view"]["columns"]]
    rows = [[v if v is not None else "" for v in r] for r in d["data"]]
    assert col_names[0] == "sid"
    assert col_names[MAKE_IDX] == "Make"
    yield OtusTestData(col_names, rows)


@pytest.fixture
def redis():
    yield Redis()


def test_otus16_str_write(redis, data):
    redis.flushdb()
    c = data.cols[1:]
    with redis.pipeline(transaction=False) as p:
        for n, row in enumerate(data.rows):
            head = f"{keyhead}:{row[0]}"
            for k, v in zip(c, row[1:]):
                p.set(f"{head}:{k}", v)
            if n % 10000:
                p.execute()
        p.execute()


@pytest.mark.order(after="test_otus16_str_write")
def test_otus16_str_count_make(redis):
    with redis.pipeline(transaction=False) as p:
        for k in redis.keys(f"{keyhead}:*:Make"):
            p.get(k) # queue commands
        result = Counter(p.execute())
    assert result == result_expected


@pytest.mark.order(after="test_otus16_str_count_make")
def test_otus16_hset_write(redis, data):
    redis.flushdb()
    c = data.cols[1:]
    with redis.pipeline(transaction=False) as p:
        for n, row in enumerate(data.rows):
            head = f"{keyhead}:{row[0]}"
            redis.hset(head, mapping=dict(zip(c, row[1:])))
            if n % 10000:
                p.execute()
        p.execute()


@pytest.mark.order(after="test_otus16_hset_write")
def test_otus16_hset_count_make(redis):
    with redis.pipeline(transaction=False) as p:
        for k in redis.keys(f"{keyhead}:*"):
            p.hget(k, "Make") # queue commands
        result = Counter(p.execute())
    assert result == result_expected


@pytest.mark.order(after="test_otus16_hash_count_make")
def test_otus16_oset_write(redis, data):
    redis.flushdb()
    c = data.cols[1:]
    oset_key = f"{keyhead}:model_rank"
    with redis.pipeline(transaction=False) as p:
        for n, row in enumerate(data.rows):
            head = f"{keyhead}:{row[0]}"
            redis.hset(head, mapping=dict(zip(c, row[1:])))
            p.zincrby(oset_key, 1, row[MAKE_IDX])
            if n % 10000:
                p.execute()
        p.execute()


@pytest.mark.order(after="test_otus16_oset_write")
def test_otus16_oset_count_make(redis):
    redis_result = dict(redis.zrange(f"{keyhead}:model_rank", 0, -1, withscores=True))
    # zrange counts are floats not ints, so type cast required
    result = {k:int(v) for k,v in redis_result.items()}
    assert result == result_expected


@pytest.mark.order(after="test_otus16_oset_count_make")
def test_otus16_list_write(redis, data):
    redis.flushdb()
    list_key = f"{keyhead}:list"
    with redis.pipeline(transaction=False) as p:
        for n, row in enumerate(data.rows):
            p.lpush(list_key, json.dumps(row))
            if n % 10000:
                p.execute()
        p.execute()


@pytest.mark.order(after="test_otus16_list_write")
def test_otus16_list_count_make(redis):
    list_key = f"{keyhead}:list"
    result = Counter((bytes(json.loads(item)[MAKE_IDX],"ascii")
                      for item in redis.lrange(list_key, 0, -1)))
    assert result == result_expected
