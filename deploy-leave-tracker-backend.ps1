# Deploy Leave Tracker backend from unified NutriLens repository root
param(
    [string]$ProjectId = "leave-tracker-2025",
    [string]$Region = "us-central1",
    [string]$ServiceName = "leave-tracker-api",
    [string]$RepoName = "leave-tracker-repo",
    [string]$ImageName = "backend",
    [string]$ImageTagValue = "latest",
    [string]$SecretKey = "",
    [string]$GeminiApiKey = "",
    [string]$CorsOrigins = "https://storage.googleapis.com"
)

$ErrorActionPreference = "Stop"

Write-Host "`n🚀 Deploying Leave Tracker Backend from unified repo" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`n" -ForegroundColor Gray

$ImageTag = "$Region-docker.pkg.dev/$ProjectId/$RepoName/$ImageName:$ImageTagValue"

Write-Host "Step 1/4: Configuring GCP project..." -ForegroundColor Yellow
gcloud config set project $ProjectId --quiet
gcloud config set run/region $Region --quiet
Write-Host "✓ Project configured`n" -ForegroundColor Green

Write-Host "Step 2/4: Ensuring Artifact Registry repository exists..." -ForegroundColor Yellow
$repoExists = gcloud artifacts repositories describe $RepoName --location=$Region --format="value(name)" 2>$null
if (-not $repoExists) {
    gcloud artifacts repositories create $RepoName `
        --repository-format=docker `
        --location=$Region `
        --description="Leave Tracker backend images"
    Write-Host "✓ Repository created`n" -ForegroundColor Green
} else {
    Write-Host "✓ Repository already exists`n" -ForegroundColor Green
}

Write-Host "Step 3/4: Building Leave Tracker image with Cloud Build..." -ForegroundColor Yellow
gcloud builds submit . `
    --config backend/cloudbuild.leave-tracker.yaml `
    --substitutions _IMAGE_TAG=$ImageTag
Write-Host "✓ Image built successfully`n" -ForegroundColor Green

Write-Host "Step 4/4: Deploying to Cloud Run..." -ForegroundColor Yellow

$envVars = @("ENVIRONMENT=production", "GCP_PROJECT_ID=$ProjectId", "CORS_ORIGINS=$CorsOrigins")
if ($SecretKey -ne "") {
    $envVars += "SECRET_KEY=$SecretKey"
}
if ($GeminiApiKey -ne "") {
    $envVars += "GEMINI_API_KEY=$GeminiApiKey"
}
$envVarsArg = [string]::Join(",", $envVars)

gcloud run deploy $ServiceName `
    --image=$ImageTag `
    --region=$Region `
    --platform=managed `
    --allow-unauthenticated `
    --set-env-vars=$envVarsArg `
    --quiet

$BackendUrl = gcloud run services describe $ServiceName --region=$Region --format="value(status.url)"
Write-Host "`n✅ Leave Tracker backend deployed: $BackendUrl" -ForegroundColor Green
Write-Host "API Docs: $BackendUrl/docs" -ForegroundColor Cyan
