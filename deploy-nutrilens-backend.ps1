# NutriLens backend deployment script
# Mirrors the Leave Tracker deploy-backend-update.ps1 pattern.
# Target: Cloud Run service "nutrilens-api" in project "leave-tracker-2025".

Write-Host "`n🚀 Deploying NutriLens Backend to Cloud Run" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Gray

$ProjectId  = "leave-tracker-2025"
$Region     = "us-central1"
$ServiceName = "nutrilens-api"
$RepoName   = "nutrilens-repo"
$ImageTag   = "$Region-docker.pkg.dev/$ProjectId/$RepoName/backend:latest"

$CorsOrigins = "https://storage.googleapis.com,http://localhost:5173,http://localhost:5174,http://127.0.0.1:5173,http://127.0.0.1:5174"
$GoogleClientId = ""
$GeminiApiKey = ""
$NutriLensAnalysisModel = ""

$existingEnv = @{}
try {
    $serviceJson = gcloud run services describe $ServiceName --region=$Region --project=$ProjectId --format=json | ConvertFrom-Json
    $existingEntries = $serviceJson.spec.template.spec.containers[0].env
    foreach ($entry in $existingEntries) {
        if ($entry.name) {
            $existingEnv[$entry.name] = $entry.value
        }
    }
} catch {
    $existingEnv = @{}
}

if (Test-Path "frontend/.env.production") {
    $prodMatch = Select-String -Path "frontend/.env.production" -Pattern '^VITE_GOOGLE_CLIENT_ID=(.+)$'
    if ($prodMatch) {
        $GoogleClientId = $prodMatch.Matches[0].Groups[1].Value.Trim()
    }
}

if (-not $GoogleClientId -and (Test-Path "frontend/.env.development")) {
    $devMatch = Select-String -Path "frontend/.env.development" -Pattern '^VITE_GOOGLE_CLIENT_ID=(.+)$'
    if ($devMatch) {
        $GoogleClientId = $devMatch.Matches[0].Groups[1].Value.Trim()
    }
}

if (Test-Path "backend/.env") {
    $geminiMatch = Select-String -Path "backend/.env" -Pattern '^GEMINI_API_KEY=(.+)$'
    if ($geminiMatch) {
        $GeminiApiKey = $geminiMatch.Matches[0].Groups[1].Value.Trim()
    }

    $modelMatch = Select-String -Path "backend/.env" -Pattern '^NUTRILENS_ANALYSIS_MODEL=(.+)$'
    if ($modelMatch) {
        $NutriLensAnalysisModel = $modelMatch.Matches[0].Groups[1].Value.Trim()
    }
}

if (-not $GoogleClientId -and $existingEnv.ContainsKey("GOOGLE_CLIENT_ID")) {
    $GoogleClientId = [string]$existingEnv["GOOGLE_CLIENT_ID"]
}

if (-not $GeminiApiKey -and $existingEnv.ContainsKey("GEMINI_API_KEY")) {
    $GeminiApiKey = [string]$existingEnv["GEMINI_API_KEY"]
}

if (-not $NutriLensAnalysisModel -and $existingEnv.ContainsKey("NUTRILENS_ANALYSIS_MODEL")) {
    $NutriLensAnalysisModel = [string]$existingEnv["NUTRILENS_ANALYSIS_MODEL"]
}

# ── Step 1: Configure project ──────────────────────────────────────────────────
Write-Host "Step 1/4: Configuring project..." -ForegroundColor Yellow
gcloud config set project $ProjectId --quiet
gcloud config set run/region $Region --quiet
Write-Host "✓ Project configured`n" -ForegroundColor Green

# ── Step 2: Ensure Artifact Registry repo exists ───────────────────────────────
Write-Host "Step 2/4: Ensuring Artifact Registry repository exists..." -ForegroundColor Yellow
$repoExists = gcloud artifacts repositories describe $RepoName --location=$Region --format="value(name)" 2>$null
if (-not $repoExists) {
    gcloud artifacts repositories create $RepoName `
        --repository-format=docker `
        --location=$Region `
        --description="NutriLens backend images"
    Write-Host "✓ Repository created`n" -ForegroundColor Green
} else {
    Write-Host "✓ Repository already exists`n" -ForegroundColor Green
}

# ── Step 3: Build with Cloud Build ────────────────────────────────────────────
Write-Host "Step 3/4: Building image with Cloud Build — this may take 2-3 minutes..." -ForegroundColor Yellow
Push-Location backend
gcloud builds submit --tag $ImageTag

if ($LASTEXITCODE -ne 0) {
    Write-Host "`n❌ Build failed!" -ForegroundColor Red
    Pop-Location
    exit 1
}
Pop-Location
Write-Host "✓ Image built successfully`n" -ForegroundColor Green

# ── Step 4: Deploy to Cloud Run ───────────────────────────────────────────────
Write-Host "Step 4/4: Deploying to Cloud Run..." -ForegroundColor Yellow

$envFilePath = "backend/cloudrun-env.generated.yaml"
$envLines = @(
    "ENVIRONMENT: production",
    "GCP_PROJECT_ID: $ProjectId",
    "CORS_ORIGINS: `"$CorsOrigins`""
)
if ($GoogleClientId) {
    $envLines += "GOOGLE_CLIENT_ID: $GoogleClientId"
}
if ($GeminiApiKey) {
    $envLines += "GEMINI_API_KEY: $GeminiApiKey"
}
if ($NutriLensAnalysisModel) {
    $envLines += "NUTRILENS_ANALYSIS_MODEL: $NutriLensAnalysisModel"
}
Set-Content -Path $envFilePath -Value ($envLines -join "`n") -Encoding UTF8

gcloud run deploy $ServiceName `
    --image=$ImageTag `
    --region=$Region `
    --platform=managed `
    --env-vars-file=$envFilePath `
    --allow-unauthenticated `
    --quiet

if (Test-Path $envFilePath) {
    Remove-Item $envFilePath -Force
}

if ($LASTEXITCODE -eq 0) {
    $BackendUrl = gcloud run services describe $ServiceName --region=$Region --format="value(status.url)"
    Write-Host ""
    Write-Host "========================================================" -ForegroundColor Green
    Write-Host "         DEPLOYMENT SUCCESSFUL!                         " -ForegroundColor Green
    Write-Host "========================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Backend URL : $BackendUrl" -ForegroundColor Cyan
    Write-Host "API Docs    : $BackendUrl/docs" -ForegroundColor Cyan
    Write-Host "Health      : $BackendUrl/health" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Update Flutter api_config.dart:" -ForegroundColor Yellow
    Write-Host "  kBackendBaseUrl = '$BackendUrl'" -ForegroundColor White
} else {
    Write-Host "`n❌ Deployment failed!" -ForegroundColor Red
    exit 1
}
