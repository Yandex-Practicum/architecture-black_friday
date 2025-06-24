rs.initiate(
    {
      _id : shardName,
      members: [
        { _id : shardId, host : primaryHostAndPort },
      ]
    }
);

