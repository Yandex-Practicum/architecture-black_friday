rs.initiate({
  _id: "shard2ReplSet",
  members: [
    { _id: 0, host: "shard2-primary:27023" },
    { _id: 1, host: "shard2-secondary1:27024" },
    { _id: 2, host: "shard2-secondary2:27025" }
  ]
})