// Основной JavaScript для онлайн-магазина "Мобильный мир"

document.addEventListener('DOMContentLoaded', function() {
    // Показываем CDN индикатор
    showCDNIndicator();
    
    // Инициализируем интерактивные элементы
    initProductCards();
    initNavigation();
    initScrollEffects();
});

// Функция для показа CDN индикатора
function showCDNIndicator() {
    const indicator = document.createElement('div');
    indicator.className = 'cdn-indicator';
    indicator.innerHTML = '🚀 CDN: Европа';
    
    // Определяем регион на основе порта или других параметров
    const port = window.location.port;
    let region = 'Глобальный';
    
    if (port === '8091') {
        region = 'Европа';
        indicator.innerHTML = '🇪🇺 CDN: Европа';
    } else if (port === '8092') {
        region = 'Азия';
        indicator.innerHTML = '🇦🇸 CDN: Азия';
    } else if (port === '8093') {
        region = 'Америка';
        indicator.innerHTML = '🇺🇸 CDN: Америка';
    }
    
    document.body.appendChild(indicator);
    
    // Показываем информацию о CDN в консоли
    console.log(`🌍 CDN узел: ${region}`);
    console.log(`⚡ Загрузка через CDN ускоряет доставку контента`);
}

// Инициализация карточек товаров
function initProductCards() {
    const productCards = document.querySelectorAll('.product-card');
    
    productCards.forEach(card => {
        const button = card.querySelector('button');
        const productName = card.querySelector('h3').textContent;
        
        button.addEventListener('click', function() {
            addToCart(productName);
        });
        
        // Добавляем эффект при наведении
        card.addEventListener('mouseenter', function() {
            this.style.transform = 'translateY(-10px) scale(1.02)';
        });
        
        card.addEventListener('mouseleave', function() {
            this.style.transform = 'translateY(0) scale(1)';
        });
    });
}

// Функция добавления в корзину
function addToCart(productName) {
    // Показываем уведомление
    showNotification(`${productName} добавлен в корзину!`);
    
    // Здесь можно добавить логику для работы с корзиной
    console.log(`🛒 Добавлен в корзину: ${productName}`);
}

// Показ уведомлений
function showNotification(message) {
    const notification = document.createElement('div');
    notification.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        background: #667eea;
        color: white;
        padding: 1rem 2rem;
        border-radius: 10px;
        box-shadow: 0 5px 15px rgba(0,0,0,0.3);
        z-index: 10000;
        transform: translateX(100%);
        transition: transform 0.3s ease;
    `;
    notification.textContent = message;
    
    document.body.appendChild(notification);
    
    // Анимация появления
    setTimeout(() => {
        notification.style.transform = 'translateX(0)';
    }, 100);
    
    // Автоматическое скрытие
    setTimeout(() => {
        notification.style.transform = 'translateX(100%)';
        setTimeout(() => {
            document.body.removeChild(notification);
        }, 300);
    }, 3000);
}

// Инициализация навигации
function initNavigation() {
    const navLinks = document.querySelectorAll('nav a');
    
    navLinks.forEach(link => {
        link.addEventListener('click', function(e) {
            // Добавляем эффект при клике
            this.style.transform = 'scale(0.95)';
            setTimeout(() => {
                this.style.transform = 'scale(1)';
            }, 150);
        });
    });
}

// Эффекты при прокрутке
function initScrollEffects() {
    window.addEventListener('scroll', function() {
        const scrolled = window.pageYOffset;
        const parallax = document.querySelector('.hero');
        
        if (parallax) {
            const speed = scrolled * 0.5;
            parallax.style.transform = `translateY(${speed}px)`;
        }
    });
}

// Функция для измерения производительности CDN
function measureCDNPerformance() {
    const startTime = performance.now();
    
    // Загружаем тестовый ресурс
    const testImage = new Image();
    testImage.onload = function() {
        const endTime = performance.now();
        const loadTime = endTime - startTime;
        
        console.log(`⚡ Время загрузки через CDN: ${loadTime.toFixed(2)}ms`);
        
        // Показываем результат пользователю
        if (loadTime < 100) {
            showNotification('🚀 Отличная скорость CDN!');
        } else if (loadTime < 300) {
            showNotification('⚡ Хорошая скорость CDN');
        } else {
            showNotification('🐌 Медленная загрузка');
        }
    };
    
    testImage.src = '/images/test-image.jpg?' + Date.now();
}

// Автоматическое измерение производительности при загрузке
window.addEventListener('load', function() {
    setTimeout(measureCDNPerformance, 1000);
});

// Функция для переключения между CDN регионами (для демонстрации)
function switchCDNRegion(region) {
    const regions = {
        'europe': 'http://localhost:8091',
        'asia': 'http://localhost:8092',
        'america': 'http://localhost:8093'
    };
    
    if (regions[region]) {
        window.location.href = regions[region];
    }
}

// Добавляем глобальные функции для демонстрации
window.switchCDNRegion = switchCDNRegion;
window.measureCDNPerformance = measureCDNPerformance; 