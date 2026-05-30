# ============================================================
#  PocketPilot Dev Launcher
#  Auto-detects your LAN IP and starts backend + Flutter app.
#  Usage:  powershell -ExecutionPolicy Bypass -File run_dev.ps1
# ============================================================

$PORT = 8000

# ── 1. Detect the active LAN IPv4 address ───────────────────
# Picks the first non-loopback, non-APIPA address on a connected adapter.
$ip = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object {
        $_.IPAddress -notlike "127.*"   -and
        $_.IPAddress -notlike "169.254.*" -and
        $_.PrefixOrigin -ne "WellKnown"
    } |
    Sort-Object InterfaceMetric |
    Select-Object -First 1).IPAddress

if (-not $ip) {
    Write-Error "Could not detect a valid LAN IP address. Are you connected to a network?"
    exit 1
}

$BASE_URL = "http://${ip}:${PORT}/api"
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  PocketPilot Dev Launcher" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Detected IP  : $ip" -ForegroundColor Green
Write-Host "  Backend URL  : $BASE_URL" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# ── 2. Start the backend in a new terminal window ───────────
$backendPath = Join-Path $PSScriptRoot "backend"
Write-Host "[1/2] Starting backend (npm run dev) in new window..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Set-Location '$backendPath'; npm run dev"

# Give the backend a moment to boot before Flutter connects
Start-Sleep -Seconds 3

# ── 3. Start Flutter with the correct BASE_URL ──────────────
$flutterPath = Join-Path $PSScriptRoot "pocket_pilot"
Write-Host "[2/2] Starting Flutter app with BASE_URL=$BASE_URL ..." -ForegroundColor Yellow
Write-Host ""
Set-Location $flutterPath
flutter run `
    --dart-define="BASE_URL=$BASE_URL" `
    --dart-define="GEMINI_CHAT_KEY=$env:GEMINI_CHAT_KEY" `
    --dart-define="GEMINI_RECEIPT_KEY=$env:GEMINI_RECEIPT_KEY"
