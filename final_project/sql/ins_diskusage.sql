INSERT INTO archive.diskusage
SELECT HOSTNAME as hostname
     , DEV as dev
     , SAMPLE_TIME as t
     , TOTAL as total_bytes
     , USED as used_bytes
  FROM s3Cluster('{cluster}',
          'https://storage.yandexcloud.net/abone27-otus99/host*.csv.gz',
          'CSVWithNames')
;
