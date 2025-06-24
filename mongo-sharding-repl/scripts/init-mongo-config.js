rs.initiate(
  {
    _id : "configReplSet",
       configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" }
    ]
  }
);