FROM python:3.13-slim

ENV PYTHONUNBUFFERED=1 PIP_NO_CACHE_DIR=1
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY main.py tools.py ./

# ENTRYPOINT statt CMD: das Argument (die Execution-ID) kommt beim Start des Jobs dazu.
ENTRYPOINT ["python", "main.py"]
