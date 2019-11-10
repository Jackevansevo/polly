FROM python:3.8
EXPOSE 8000/tcp
COPY requirements.txt /
RUN pip install -U pip && pip install -r requirements.txt
COPY app.py poll.py ./
