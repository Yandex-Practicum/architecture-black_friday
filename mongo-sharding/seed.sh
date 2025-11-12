docker exec -t mongos_router mongosh --port 27020 --eval '
  for(var i = 0; i < 1000; i++) db.helloDoc.insertOne({age:i, name:"ly"+i})
' somedb