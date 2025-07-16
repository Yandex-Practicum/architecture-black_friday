#!/bin/bash

URL="http://localhost:8080/test/users"
ITERATIONS=3

echo "Тестируем отклик эндпоинта: $URL"
echo "Выполняем $ITERATIONS последовательных запроса..."

for i in $(seq 1 $ITERATIONS); do
    echo -n "Запрос $i: "

    start=$(date +%s%3N)  # миллисекунды
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$URL")
    end=$(date +%s%3N)

    elapsed=$((end - start))
    echo "$elapsed мс (HTTP $http_code)"
done
