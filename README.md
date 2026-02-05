# Проектная работа 4 спринта.
# Шардирование и репликация

## Задание 1. Планирование
Составлены три схемы на основе шаблона.
Схемы расположены: [./schemas/](/schemas/)

## Задание 2. Шардирование
Реализовано в [mongo-sharding](/mongo-sharding/).<br>
Инструкция по запуску и проверке лежит в [README.MD](/mongo-sharding/README.md)

## Задание 3. Репликация
Реализовано в [mongo-sharding-repl](/mongo-sharding-repl/).<br>
Инструкция по запуску и проверке лежит в [README.MD](/mongo-sharding-repl/README.md)

## Задание 4. Кеширование
Реализовано в [sharding-repl-cache](/sharding-repl-cache/) для четвёртого задания.<br>
Инструкция по запуску и проверке лежит в [README.MD](/sharding-repl-cache/README.md)

## Задание 5. Service Discovery и балансировка с API Gateway
В ходе выполнения задания составлен четвёртый вариант схемы, на котором вы показана реализацию горизонтального масштабирования сайта. Для этого за основу взят третий вариант, добавлен на схему API Gateway для балансировки и Consul для Service Discovery.
Финальная схема этого задания: [./schemas/task1_4.drawio](/schemas/task_1.4.drawio)
Финальная схема этого задания: [./schemas/task1_4.png](/schemas/task_1.4.png)

## Задание 6. CDN
Доработана четвёртая схема.<br>
На схеме отображен CDN, взаимодействие пользователей из разных регионов с CDN.  
Финальная схема этого задания: [./schemas/task1_5.drawio](/schemas/task1_5.drawio)
Финальная схема этого задания: [./schemas/task1_5.png](/schemas/task1_5.png)
