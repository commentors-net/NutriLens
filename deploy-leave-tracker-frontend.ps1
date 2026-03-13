# Deploy unified frontend from the NutriLens repository root.
param(
    [string]$ProjectId = "leave-tracker-2025",
    [string]$BucketName = "leave-tracker-2025-frontend",
    [string]$ApiUrl = "",
    [switch]$CleanBucket
)

$ErrorActionPreference = "Stop"

Write-Host "`nDeploying frontend from unified repo" -ForegroundColor Cyan
Write-Host "-----------------------------------`n" -ForegroundColor Gray

$frontendPath = "frontend"
if (-not (Test-Path $frontendPath)) {
    Write-Host "ERROR: Frontend folder not found: $frontendPath" -ForegroundColor Red
    exit 1
}

if ($ApiUrl -ne "") {
    "VITE_API_URL=$ApiUrl" | Out-File -FilePath "$frontendPath\.env.production" -Encoding utf8
    "VITE_ENABLE_REGISTRATION=true" | Out-File -FilePath "$frontendPath\.env.production" -Append -Encoding utf8
}

Write-Host "Step 1/4: Building frontend..." -ForegroundColor Yellow
Push-Location $frontendPath
npm install
npm run build:prod
Pop-Location
Write-Host "Build successful.`n" -ForegroundColor Green

Write-Host "Step 2/4: Optional clean..." -ForegroundColor Yellow
if ($CleanBucket.IsPresent) {
    gcloud storage rm -r "gs://$BucketName/*" --project=$ProjectId 2>$null
    Write-Host "Bucket cleaned.`n" -ForegroundColor Green
} else {
    Write-Host "Skip clean (use -CleanBucket to enable).`n" -ForegroundColor Green
}

Write-Host "Step 3/4: Uploading build output..." -ForegroundColor Yellow
gcloud storage cp "$frontendPath/dist/index.html" "gs://$BucketName/" --project=$ProjectId
if (Test-Path "$frontendPath/dist/version.json") {
    gcloud storage cp "$frontendPath/dist/version.json" "gs://$BucketName/" --project=$ProjectId
}
if (Test-Path "$frontendPath/dist/assets") {
    gcloud storage cp -r "$frontendPath/dist/assets" "gs://$BucketName/" --project=$ProjectId
}
if (Test-Path "$frontendPath/dist/public") {
    gcloud storage cp -r "$frontendPath/dist/public" "gs://$BucketName/" --project=$ProjectId
}
Write-Host "Upload successful.`n" -ForegroundColor Green

Write-Host "Step 4/4: Setting cache-control..." -ForegroundColor Yellow
gcloud storage objects update "gs://$BucketName/index.html" `
    --cache-control="no-cache, no-store, must-revalidate" `
    --project=$ProjectId

if (Test-Path "$frontendPath/dist/version.json") {
    gcloud storage objects update "gs://$BucketName/version.json" `
        --cache-control="no-cache, no-store, must-revalidate" `
        --project=$ProjectId
}

if (Test-Path "$frontendPath/dist/assets") {
    gcloud storage objects update "gs://$BucketName/assets/**" `
        --cache-control="public, max-age=31536000, immutable" `
        --project=$ProjectId
}

Write-Host "`nFrontend deployment completed." -ForegroundColor Green
Write-Host "URL: https://storage.googleapis.com/$BucketName/index.html" -ForegroundColor Cyan
