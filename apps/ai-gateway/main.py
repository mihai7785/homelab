import os
import uuid
import httpx
import base64
from datetime import datetime
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST
from starlette.responses import Response
import time

app = FastAPI(
    title="AI Gateway",
    description="Natural language to Kubernetes manifests via GitOps",
    version="1.0.0"
)

# --- Config from environment ---
OLLAMA_URL = os.getenv("OLLAMA_URL", "http://192.168.1.94:11434")
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN", "")
GITHUB_REPO = os.getenv("GITHUB_REPO", "mihai7785/homelab")
GITHUB_BRANCH_BASE = os.getenv("GITHUB_BRANCH_BASE", "main")
MANIFEST_PATH_PREFIX = os.getenv("MANIFEST_PATH_PREFIX", "gitops/apps/ai-generated")
OLLAMA_MODEL = os.getenv("OLLAMA_MODEL", "qwen2.5-coder:7b")

# --- Prometheus metrics ---
REQUEST_COUNT = Counter(
    "ai_gateway_requests_total",
    "Total requests to AI Gateway",
    ["endpoint", "status"]
)
GENERATION_DURATION = Histogram(
    "ai_gateway_generation_duration_seconds",
    "Time spent generating manifests",
    ["type"]
)
PR_COUNT = Counter(
    "ai_gateway_prs_created_total",
    "Total PRs created by AI Gateway",
    ["status"]
)

# --- Request/Response models ---
class ManifestRequest(BaseModel):
    prompt: str
    app_name: str | None = None

class ManifestResponse(BaseModel):
    pr_url: str
    branch: str
    manifest: str
    app_name: str

# --- System prompt for Kubernetes manifest generation ---
K8S_SYSTEM_PROMPT = """You are a Kubernetes manifest generator for a homelab platform.
Generate ONLY valid Kubernetes YAML manifests based on the user's request.
Always include these elements:
- Namespace: ai-generated
- Proper labels: app.kubernetes.io/name, app.kubernetes.io/managed-by: ai-gateway
- Resource requests and limits (use small values for homelab: 100m CPU, 128Mi memory)
- For Deployments: always include a Service as well
Output ONLY the YAML, no explanation, no markdown code blocks, no extra text.
Separate multiple resources with ---
"""

@app.get("/health")
def health():
    return {"status": "healthy", "ollama": OLLAMA_URL, "model": OLLAMA_MODEL}

@app.get("/metrics")
def metrics():
    return Response(generate_latest(), media_type=CONTENT_TYPE_LATEST)

@app.post("/generate/manifest", response_model=ManifestResponse)
async def generate_manifest(request: ManifestRequest):
    REQUEST_COUNT.labels(endpoint="generate_manifest", status="started").inc()
    start = time.time()

    # 1. Generate manifest via Ollama
    try:
        manifest = await call_ollama(request.prompt, K8S_SYSTEM_PROMPT)
    except Exception as e:
        REQUEST_COUNT.labels(endpoint="generate_manifest", status="ollama_error").inc()
        raise HTTPException(status_code=502, detail=f"Ollama error: {str(e)}")

    GENERATION_DURATION.labels(type="manifest").observe(time.time() - start)

    # 2. Derive app name
    app_name = request.app_name or f"ai-app-{uuid.uuid4().hex[:6]}"
    branch = f"ai-gateway/{app_name}-{uuid.uuid4().hex[:6]}"
    file_path = f"{MANIFEST_PATH_PREFIX}/{app_name}.yaml"

    # 3. Create PR on GitHub
    try:
        pr_url = await create_github_pr(
            branch=branch,
            file_path=file_path,
            content=manifest,
            app_name=app_name,
            prompt=request.prompt
        )
    except Exception as e:
        REQUEST_COUNT.labels(endpoint="generate_manifest", status="github_error").inc()
        raise HTTPException(status_code=502, detail=f"GitHub error: {str(e)}")

    PR_COUNT.labels(status="created").inc()
    REQUEST_COUNT.labels(endpoint="generate_manifest", status="success").inc()

    return ManifestResponse(
        pr_url=pr_url,
        branch=branch,
        manifest=manifest,
        app_name=app_name
    )

async def call_ollama(prompt: str, system_prompt: str) -> str:
    async with httpx.AsyncClient(timeout=120.0) as client:
        response = await client.post(
            f"{OLLAMA_URL}/api/generate",
            json={
                "model": OLLAMA_MODEL,
                "prompt": prompt,
                "system": system_prompt,
                "stream": False,
                "options": {
                    "temperature": 0.1,
                    "top_p": 0.9,
                }
            }
        )
        response.raise_for_status()
        return response.json()["response"].strip()

async def create_github_pr(
    branch: str,
    file_path: str,
    content: str,
    app_name: str,
    prompt: str
) -> str:
    headers = {
        "Authorization": f"token {GITHUB_TOKEN}",
        "Accept": "application/vnd.github.v3+json",
        "X-GitHub-Api-Version": "2022-11-28"
    }
    base_url = f"https://api.github.com/repos/{GITHUB_REPO}"

    async with httpx.AsyncClient(timeout=30.0) as client:
        # Get base branch SHA
        ref_resp = await client.get(
            f"{base_url}/git/ref/heads/{GITHUB_BRANCH_BASE}",
            headers=headers
        )
        ref_resp.raise_for_status()
        base_sha = ref_resp.json()["object"]["sha"]

        # Create new branch
        branch_resp = await client.post(
            f"{base_url}/git/refs",
            headers=headers,
            json={"ref": f"refs/heads/{branch}", "sha": base_sha}
        )
        branch_resp.raise_for_status()

        # Create file on branch
        content_b64 = base64.b64encode(content.encode()).decode()
        file_resp = await client.put(
            f"{base_url}/contents/{file_path}",
            headers=headers,
            json={
                "message": f"feat(ai-generated): add manifest for {app_name}",
                "content": content_b64,
                "branch": branch
            }
        )
        file_resp.raise_for_status()

        # Create PR
        pr_resp = await client.post(
            f"{base_url}/pulls",
            headers=headers,
            json={
                "title": f"[AI Gateway] Deploy {app_name}",
                "body": f"## AI Generated Manifest\n\n**Original request:** {prompt}\n\n**Model:** {OLLAMA_MODEL}\n\n**Generated at:** {datetime.utcnow().isoformat()}Z\n\n> Review the generated manifest carefully before merging.",
                "head": branch,
                "base": GITHUB_BRANCH_BASE
            }
        )
        pr_resp.raise_for_status()
        return pr_resp.json()["html_url"]
