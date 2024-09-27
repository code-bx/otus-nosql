CREATE TABLE archive.diskusage_ ON CLUSTER '{cluster}'
(
    hostname String,
    dev String,
    t DateTime('UTC'),
    total_bytes UInt128,
    used_bytes UInt128
)
ENGINE = ReplicatedMergeTree
PRIMARY KEY (hostname, dev)
ORDER BY (hostname, dev, t);

CREATE TABLE archive.diskusage ON CLUSTER '{cluster}'
(
    hostname String,
    dev String,
    t DateTime('UTC'),
    total_bytes UInt128,
    used_bytes UInt128
)
ENGINE = Distributed('{cluster}', 'archive', 'diskusage_', halfMD5(hostname,dev));
