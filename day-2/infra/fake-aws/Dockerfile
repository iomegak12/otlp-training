FROM python:3.12-slim
ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1 PIP_DISABLE_PIP_VERSION_CHECK=1
WORKDIR /app
RUN pip install boto3==1.43.108
COPY fleet.py .
ENTRYPOINT ["python", "fleet.py"]
CMD ["status"]
