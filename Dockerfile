FROM python:3.14

RUN mkdir -p /pyapp
WORKDIR /pyapp
COPY pyapp .

RUN python -m venv .venv
RUN pip install -r requirements.txt

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--reload"]
