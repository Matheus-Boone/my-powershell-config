<#
.SYNOPSIS
    Instala o perfil personalizado do PowerShell e o tema Oh My Posh.

.DESCRIPTION
    Este script copia o tema Catppuccin Mocha para ~/.config/ohmyposh/,
    gera o cache de inicialização do Oh My Posh, e instala o perfil
    do PowerShell em $PROFILE.

.NOTES
    Autor: Matheus Boone
#>

[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$ScriptDir = $PSScriptRoot

# --- Cores ---
function Write-Step { param($msg) Write-Host "  ▸ $msg" -ForegroundColor Cyan }
function Write-Ok   { param($msg) Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  ⚠ $msg" -ForegroundColor Yellow }

Write-Host ""
Write-Host "  ⚡ Instalador — My PowerShell Config" -ForegroundColor Magenta
Write-Host "  ════════════════════════════════════════" -ForegroundColor DarkGray
Write-Host ""

# 1. Verificar Oh My Posh
Write-Step "Verificando Oh My Posh..."
if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    Write-Error "Oh My Posh não encontrado. Instale primeiro: https://ohmyposh.dev/docs/installation/windows"
}
Write-Ok "Oh My Posh encontrado"

# 2. Copiar tema
$ThemeDir = "$env:USERPROFILE\.config\ohmyposh"
$ThemeSrc = Join-Path $ScriptDir "ohmyposh\catppuccin_mocha.omp.json"
$ThemeDst = Join-Path $ThemeDir "catppuccin_mocha.omp.json"

Write-Step "Copiando tema Catppuccin Mocha..."
if (-not (Test-Path $ThemeDir)) {
    New-Item -Path $ThemeDir -ItemType Directory -Force | Out-Null
}
Copy-Item $ThemeSrc $ThemeDst -Force
Write-Ok "Tema copiado para $ThemeDst"

# 3. Gerar cache de init
$CachePath = Join-Path $ThemeDir "omp_init.ps1"
Write-Step "Gerando cache de inicialização do Oh My Posh..."
oh-my-posh init pwsh --config $ThemeDst --print | Set-Content $CachePath -Encoding utf8
Write-Ok "Cache gerado em $CachePath"

# 4. Instalar perfil
$ProfileSrc = Join-Path $ScriptDir "Microsoft.PowerShell_profile.ps1"
$ProfileDir = Split-Path $PROFILE -Parent

Write-Step "Instalando perfil em $PROFILE..."

if ((Test-Path $PROFILE) -and -not $Force) {
    Write-Warn "Perfil já existe em $PROFILE"
    $response = Read-Host "  Deseja substituir? (s/N)"
    if ($response -notin @('s', 'S', 'sim', 'Sim')) {
        Write-Host ""
        Write-Host "  Instalação cancelada. Use -Force para pular a confirmação." -ForegroundColor Yellow
        return
    }
}

if (-not (Test-Path $ProfileDir)) {
    New-Item -Path $ProfileDir -ItemType Directory -Force | Out-Null
}
Copy-Item $ProfileSrc $PROFILE -Force
Write-Ok "Perfil instalado"

# 5. Resumo
Write-Host ""
Write-Host "  ══════════════════════════════════════════" -ForegroundColor DarkGray
Write-Host "  ✅ Instalação concluída!" -ForegroundColor Green
Write-Host "     Reabra o terminal para aplicar." -ForegroundColor Gray
Write-Host ""
