from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def root():
    return {"message": "Hello from the Internal Developer Platform!", "version": "0.1.0"}

@app.get("/health")
def health():
    return {"status": "ok"}
