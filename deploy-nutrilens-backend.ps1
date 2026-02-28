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
gcloud run deploy $ServiceName `
    --image=$ImageTag `
    --region=$Region `
    --platform=managed `
    --set-env-vars="ENVIRONMENT=production,GCP_PROJECT_ID=$ProjectId" `
    --allow-unauthenticated `
    --quiet

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
