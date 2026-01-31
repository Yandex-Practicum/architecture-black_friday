#!/bin/bash

echo "🧪 Тестирование всех конфигураций MongoDB"

# Функция для тестирования конфигурации
test_config() {
    local config_name=$1
    local config_dir=$2
    
    echo "=========================================="
    echo "🔍 Тестирование: $config_name"
    echo "=========================================="
    
    cd "$config_dir" || {
        echo "❌ Директория $config_dir не найдена"
        return 1
    }
    
    echo "🚀 Запуск сервисов..."
    docker compose down -v 2>/dev/null
    docker compose up -d
    
    echo "⏳ Ожидание запуска сервисов..."
    sleep 60
    
    echo "🔧 Инициализация кластера..."
    if [ -f "init-sharding-repl.sh" ]; then
        chmod +x init-sharding-repl.sh
        ./init-sharding-repl.sh
    elif [ -f "init-sharding.sh" ]; then
        chmod +x init-sharding.sh
        ./init-sharding.sh
    else
        echo "❌ Скрипт инициализации не найден"
        return 1
    fi
    
    echo "⏳ Ожидание готовности API..."
    sleep 30
    
    echo "🌐 Проверка API..."
    if curl -s http://localhost:8080 > /dev/null; then
        echo "✅ API доступен"
        echo "📊 Информация о кластере:"
        curl -s http://localhost:8080 | jq '.' 2>/dev/null || curl -s http://localhost:8080
    else
        echo "❌ API недоступен"
        echo "📋 Логи API:"
        docker compose logs --tail=20 pymongo_api
    fi
    
    echo "🛑 Остановка сервисов..."
    docker compose down -v
    
    echo "✅ Тестирование $config_name завершено"
    echo ""
}

# Тестирование всех конфигураций
test_config "mongo-sharding" "mongo-sharding"
test_config "mongo-sharding-repl" "mongo-sharding-repl"
test_config "sharding-repl-cache" "sharding-repl-cache"

echo "🎉 Тестирование всех конфигураций завершено!"
