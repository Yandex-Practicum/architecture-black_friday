FROM python:3.12.1-slim
WORKDIR /app
EXPOSE 8080
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*
COPY requirements.txt ./
# Устанавливаем зависимости python не пересобирая их
RUN pip install --no-cache --no-cache-dir -r requirements.txt
# Копирование кода приложения
COPY app.py /app/
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080"]
