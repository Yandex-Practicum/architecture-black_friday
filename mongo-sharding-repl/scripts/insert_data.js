use somedb;
for (let i = 0; i < 1000; i++) {
  db.helloDoc.insert({ age: i, name: "ly" + i });
}
print("Вставка завершена, всего документов: " + db.helloDoc.countDocuments());