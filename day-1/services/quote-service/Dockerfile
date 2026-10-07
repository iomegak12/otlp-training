FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt && opentelemetry-bootstrap -a install
COPY app.py start.sh ./
EXPOSE 8000
CMD ["sh", "start.sh"]
