#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import csv
import datetime
import logging
import random


RND_SEED=12345678

HOST_COUNT=50

SAMPLE_STEP_SEC=60
SAMPLE_YEARS=5
SAMPLE_KEEP_SEC=SAMPLE_YEARS*365*24*60*60
SAMPLE_COUNT=SAMPLE_KEEP_SEC/SAMPLE_STEP_SEC


DEV_SCHEMAS = [
    ['/', '/srv'],
    ['/', '/var/lib/mysql'],
    ['/', '/u01', '/u02', '/u03']
]


logging.basicConfig(level=logging.INFO)
log = logging.getLogger()

def dev_size(used_bytes):
    return (used_bytes*2)>>30<<30



random.seed(RND_SEED)
for host in range(HOST_COUNT):
    hostname = f"host{host}"
    writer = csv.writer(open(f"data/{hostname}.csv","w"))
    writer.writerow(["HOSTNAME", "DEV", "SAMPLE_TIME", "TOTAL", "USED"])
    dev_schema = DEV_SCHEMAS[random.randint(0, len(DEV_SCHEMAS)-1)]
    for dev in dev_schema:
        log.info(f"Generating {hostname}[{dev}] ...")
        t1 = datetime.datetime.now()
        t0 = t1 - datetime.timedelta(seconds=SAMPLE_KEEP_SEC)
        t, tstep = t0, datetime.timedelta(seconds=SAMPLE_STEP_SEC)
        shrink_num = random.randint(3*SAMPLE_YEARS,7*SAMPLE_YEARS)
        shrink_hwm = 1 - shrink_num / SAMPLE_COUNT
        grow_num = random.randint(21*SAMPLE_YEARS,57*SAMPLE_YEARS)
        grow_hwm = 1 - grow_num / SAMPLE_COUNT
        grow_trend = 0
        du_init = int(random.randint(10,100) * 2<<30)
        du_trend = random.randint(5,300)<<30
        du_trend //= (30*24*60*60 // SAMPLE_STEP_SEC)
        du_total = int(dev_size(du_init))
        du_tot_lwm = int(du_total * 0.85)
        du = du_init
        while t < t1:
            if grow_trend and grow_left:
                grow_left -= 1
                du += int(grow_trend + random.gauss(grow_trend, grow_trend>>2))
            elif random.random() > shrink_hwm:
                du = int(du * random.uniform(0.3, 0.7))
            elif random.random() > grow_hwm:
                grow_trend = int(du_trend * random.uniform(5,50))
                grow_left = int(random.uniform(1,4)*3600/SAMPLE_STEP_SEC)
            else:
                du += int(du_trend + random.gauss(du_trend>>3, du_trend>>3))
            if du > du_tot_lwm:
                du_total = dev_size(du)
                du_tot_lwm = int(du_total * 0.85)
            row = ( f"{hostname}", dev, t.strftime("%Y-%m-%d %H:%M:%S"), du_total, du )
            writer.writerow(row)
            t += tstep
