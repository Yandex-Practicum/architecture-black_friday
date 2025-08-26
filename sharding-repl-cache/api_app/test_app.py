FROM python:3.12.1-slim
WORKDIR /app
EXPOSE 8080
COPY requirements.txt ./
RUN pip install --no-cache --no-cache-dir -r requirements.txt
COPY test_app.py /app/app.py
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8080"]