# Installs or updates GSPMH with Docker Desktop on Windows.
#   .\install.ps1          GSPMH
#   .\install.ps1 -Vpn     GSPMH with VPN tunnels (gives the API access to the Docker socket)
# The first run writes .env with random passwords and keys; later runs keep it and update the images.
param([switch]$Vpn)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Host 'Docker Desktop is not installed: https://docs.docker.com/desktop/setup/install/windows-install/'
    exit 1
}

function New-RandomText([int]$Length) {
    $chars = [char[]](48..57 + 65..90 + 97..122)
    $bytes = New-Object byte[] $Length
    [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    -join ($bytes | ForEach-Object { $chars[$_ % $chars.Length] })
}

if (-not (Test-Path .env)) {
    $text = [IO.File]::ReadAllText((Join-Path $PSScriptRoot '.env.example'))
    $text = $text -replace '(?m)^POSTGRES_PASSWORD=.*$', "POSTGRES_PASSWORD=$(New-RandomText 32)"
    $text = $text -replace '(?m)^JWT_SECRET_KEY=.*$', "JWT_SECRET_KEY=$(New-RandomText 64)"
    $text = $text -replace '(?m)^ENCRYPTION_KEY=.*$', "ENCRYPTION_KEY=$(New-RandomText 48)"
    [IO.File]::WriteAllText((Join-Path $PSScriptRoot '.env'), $text, (New-Object System.Text.UTF8Encoding $false))
    Write-Host '.env created with random passwords and keys. Keep a copy of it in a safe place.'
}

$files = @('-f', 'docker-compose.yml')
if ($Vpn) { $files += @('-f', 'docker-compose.vpn.yml') }

docker compose @files pull
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
docker compose @files up -d
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$port = ((Get-Content .env | Where-Object { $_ -match '^WEB_PORT=' }) -replace '^WEB_PORT=', '')
if (-not $port) { $port = '80' }
Write-Host ''
Write-Host "GSPMH is starting. Open http://localhost:$port and complete the setup wizard."
