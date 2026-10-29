import os
from fastapi import FastAPI

app = FastAPI(title="Cloud Platform Engineering - LAB 3")

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/")
def root():
    return {"message": "Hello from LAB 3", "environment": os.getenv("APP_ENV", "local")}
