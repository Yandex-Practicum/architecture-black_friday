// init-config-replica.js
rs.initiate({
  _id: "configReplSet",
  configsvr: true,
  members: [
    { _id: 0, host: "configmongo:27019" }
  ]
})