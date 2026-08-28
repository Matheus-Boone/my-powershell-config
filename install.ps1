<#
.SYNOPSIS
    Instalador completo do perfil personalizado do PowerShell (do zero).

.DESCRIPTION
    Prepara uma máquina Windows nova para usar esta configuração:
      1. Valida o PowerShell 7+ e ajusta a ExecutionPolicy do usuário.
      2. Instala o Oh My Posh e o fzf (via winget) se estiverem faltando.
      3. Instala os módulos: PSReadLine, z, PSFzf, Terminal-Icons.
      4. Copia o tema Catppuccin Mocha para ~\.config\ohmyposh\.
      5. Gera o cache de inicialização do Oh My Posh.
      6. Instala o perfil em $PROFILE (com backup do perfil existente).
      7. Aplica a personalização visual no settings.json do Windows Terminal
         (merge não-destrutivo, com backup).

.PARAMETER Force
    Não pergunta nada: sobrescreve o perfil e aplica a personalização do
    Windows Terminal sem confirmar (sempre gera backup antes).

.PARAMETER SkipInstall
    Pula a instalação de dependências (Oh My Posh, fzf, módulos).
    Use se você já gerencia essas ferramentas por conta própria.

.PARAMETER SkipTerminal
    Não mexe no settings.json do Windows Terminal.

.EXAMPLE
    .\install.ps1

.EXAMPLE
    .\install.ps1 -Force

.NOTES
    Autor: Matheus Boone
#>

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SkipInstall,
    [switch]$SkipTerminal
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# TLS 1.2 para PSGallery em sistemas antigos (inofensivo no PS7)
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}

# --- Saída bonitinha ---
function Write-Step { param($msg) Write-Host "  ▸ $msg" -ForegroundColor Cyan }
function Write-Ok   { param($msg) Write-Host "  ✓ $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "  ⚠ $msg" -ForegroundColor Yellow }
function Write-Err  { param($msg) Write-Host "  ✗ $msg" -ForegroundColor Red }

Write-Host ""
Write-Host "  ⚡ Instalador — My PowerShell Config" -ForegroundColor Magenta
Write-Host "  ════════════════════════════════════════" -ForegroundColor DarkGray
Write-Host ""

# ─────────────────────────────────────────────────────────────────────
# 0. Sanidade: rodar como arquivo (não colado no terminal)
# ─────────────────────────────────────────────────────────────────────
$ScriptDir = $PSScriptRoot
if (-not $ScriptDir) {
    Write-Err "Rode o arquivo diretamente:  .\install.ps1"
    Write-Err "(não cole o conteúdo do script no terminal)"
    exit 1
}

# ─────────────────────────────────────────────────────────────────────
# 1. PowerShell 7+
# ─────────────────────────────────────────────────────────────────────
Write-Step "Verificando versão do PowerShell..."
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Err "Este perfil exige PowerShell 7+. Você está no $($PSVersionTable.PSVersion)."
    Write-Host ""
    Write-Host "  Instale com:   winget install --id Microsoft.PowerShell -e" -ForegroundColor Gray
    Write-Host "  Depois abra o 'PowerShell 7' e rode este script de novo." -ForegroundColor Gray
    Write-Host ""
    exit 1
}
Write-Ok "PowerShell $($PSVersionTable.PSVersion)"

# ─────────────────────────────────────────────────────────────────────
# 2. ExecutionPolicy (para o perfil carregar no boot)
# ─────────────────────────────────────────────────────────────────────
Write-Step "Verificando ExecutionPolicy (CurrentUser)..."
$cu = Get-ExecutionPolicy -Scope CurrentUser
if ($cu -in @('Restricted', 'AllSigned', 'Undefined')) {
    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
        Write-Ok "ExecutionPolicy do usuário ajustada para RemoteSigned"
    } catch {
        Write-Warn "Não consegui alterar a ExecutionPolicy: $($_.Exception.Message)"
        Write-Warn "Rode manualmente: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"
    }
} else {
    Write-Ok "ExecutionPolicy do usuário: $cu"
}

# ─────────────────────────────────────────────────────────────────────
# Helpers de instalação
# ─────────────────────────────────────────────────────────────────────
function Update-SessionPath {
    # Recarrega o PATH do registro (útil após instalar algo via winget)
    $machine = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $user    = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = (@($machine, $user) | Where-Object { $_ }) -join ';'
}

$script:HasWinget = [bool](Get-Command winget -ErrorAction SilentlyContinue)

function Install-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Nice,
        [Parameter(Mandatory)][string]$CommandName,
        [string]$ManualUrl
    )
    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        Write-Ok "$Nice já instalado"
        return
    }
    if (-not $script:HasWinget) {
        Write-Warn "$Nice não encontrado e winget indisponível."
        if ($ManualUrl) { Write-Warn "Instale manualmente: $ManualUrl" }
        return
    }
    Write-Step "Instalando $Nice (winget)..."
    & winget install --id $Id -e --source winget --accept-package-agreements --accept-source-agreements | Out-Null
    Update-SessionPath
    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        Write-Ok "$Nice instalado"
    } else {
        Write-Warn "$Nice instalado, mas '$CommandName' não apareceu no PATH desta sessão."
        Write-Warn "Feche e reabra o terminal e rode o script de novo se algo falhar."
    }
}

function Install-PSModuleIfMissing {
    param(
        [Parameter(Mandatory)][string]$Name,
        [switch]$SkipPublisherCheck
    )
    if (Get-Module -ListAvailable -Name $Name) {
        Write-Ok "Módulo $Name já instalado"
        return
    }
    Write-Step "Instalando módulo $Name..."
    $params = @{
        Name         = $Name
        Scope        = 'CurrentUser'
        Force        = $true
        AllowClobber = $true
        Repository   = 'PSGallery'
    }
    if ($SkipPublisherCheck) { $params['SkipPublisherCheck'] = $true }
    Install-Module @params
    Write-Ok "Módulo $Name instalado"
}

# ─────────────────────────────────────────────────────────────────────
# 3. Dependências
# ─────────────────────────────────────────────────────────────────────
if ($SkipInstall) {
    Write-Warn "-SkipInstall: pulando Oh My Posh, fzf e módulos"
} else {
    Write-Host ""
    Write-Step "Dependências externas..."
    if (-not $script:HasWinget) {
        Write-Warn "winget não encontrado. Instale o 'App Installer' pela Microsoft Store"
        Write-Warn "ou instale Oh My Posh e fzf manualmente (veja o README)."
    }
    Install-WingetPackage -Id 'JanDeDobbeleer.OhMyPosh' -Nice 'Oh My Posh' -CommandName 'oh-my-posh' `
        -ManualUrl 'https://ohmyposh.dev/docs/installation/windows'
    Install-WingetPackage -Id 'junegunn.fzf' -Nice 'fzf' -CommandName 'fzf' `
        -ManualUrl 'https://github.com/junegunn/fzf/releases'

    Write-Host ""
    Write-Step "Módulos do PowerShell..."
    # Garante o provider NuGet e a PSGallery utilizável
    try { Get-PackageProvider -Name NuGet -ForceBootstrap -ErrorAction Stop | Out-Null } catch {}
    try {
        if ((Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue).InstallationPolicy -ne 'Trusted') {
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
        }
    } catch {}

    Install-PSModuleIfMissing -Name 'PSReadLine' -SkipPublisherCheck
    Install-PSModuleIfMissing -Name 'z'
    Install-PSModuleIfMissing -Name 'PSFzf'
    Install-PSModuleIfMissing -Name 'Terminal-Icons'
}

# ─────────────────────────────────────────────────────────────────────
# 4. Verificação final do Oh My Posh (obrigatório daqui pra frente)
# ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Step "Verificando Oh My Posh..."
if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    Write-Err "Oh My Posh não está disponível nesta sessão."
    Write-Err "Feche o terminal, abra de novo e rode:  .\install.ps1 -SkipInstall"
    exit 1
}
Write-Ok "Oh My Posh $((& oh-my-posh version) 2>$null)"

# ─────────────────────────────────────────────────────────────────────
# 5. Tema
# ─────────────────────────────────────────────────────────────────────
$ThemeDir = Join-Path $env:USERPROFILE '.config\ohmyposh'
$ThemeSrc = Join-Path $ScriptDir 'ohmyposh\catppuccin_mocha.omp.json'
$ThemeDst = Join-Path $ThemeDir 'catppuccin_mocha.omp.json'

if (-not (Test-Path $ThemeSrc)) {
    Write-Err "Tema não encontrado: $ThemeSrc"
    Write-Err "Rode o script de dentro da pasta do repositório clonado."
    exit 1
}

Write-Step "Copiando tema Catppuccin Mocha..."
if (-not (Test-Path $ThemeDir)) { New-Item -Path $ThemeDir -ItemType Directory -Force | Out-Null }
Copy-Item $ThemeSrc $ThemeDst -Force
Write-Ok "Tema em $ThemeDst"

# ─────────────────────────────────────────────────────────────────────
# 6. Cache de init do Oh My Posh
# ─────────────────────────────────────────────────────────────────────
$CachePath = Join-Path $ThemeDir 'omp_init.ps1'
Write-Step "Gerando cache de inicialização do Oh My Posh..."
oh-my-posh init pwsh --config $ThemeDst --print | Set-Content -Path $CachePath -Encoding utf8
Write-Ok "Cache em $CachePath"

# ─────────────────────────────────────────────────────────────────────
# 7. Perfil
# ─────────────────────────────────────────────────────────────────────
$ProfileSrc = Join-Path $ScriptDir 'Microsoft.PowerShell_profile.ps1'
$ProfileDir = Split-Path $PROFILE -Parent

Write-Host ""
Write-Step "Instalando perfil em $PROFILE"

if (Test-Path $PROFILE) {
    if (-not $Force) {
        $response = Read-Host "  Perfil já existe. Substituir? (s/N)"
        if ($response -notin @('s', 'S', 'sim', 'Sim')) {
            Write-Host ""
            Write-Warn "Instalação do perfil cancelada. Use -Force para pular a confirmação."
            Write-Host ""
            exit 0
        }
    }
    $backup = "$PROFILE.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    Copy-Item $PROFILE $backup -Force
    Write-Ok "Backup do perfil antigo: $backup"
}

if (-not (Test-Path $ProfileDir)) { New-Item -Path $ProfileDir -ItemType Directory -Force | Out-Null }
Copy-Item $ProfileSrc $PROFILE -Force
Write-Ok "Perfil instalado"

# ─────────────────────────────────────────────────────────────────────
# 8. Windows Terminal — personalização (merge não-destrutivo)
# ─────────────────────────────────────────────────────────────────────

function Remove-JsonComments {
    # Remove comentários // e /* */ respeitando o conteúdo de strings.
    param([string]$Text)
    $sb = [System.Text.StringBuilder]::new()
    $inString = $false; $escape = $false
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $c = $Text[$i]
        $n = if ($i + 1 -lt $Text.Length) { $Text[$i + 1] } else { [char]0 }
        if ($inString) {
            [void]$sb.Append($c)
            if ($escape)            { $escape = $false }
            elseif ($c -eq '\')     { $escape = $true }
            elseif ($c -eq '"')     { $inString = $false }
            continue
        }
        if ($c -eq '"') { $inString = $true; [void]$sb.Append($c); continue }
        if ($c -eq '/' -and $n -eq '/') {
            while ($i -lt $Text.Length -and $Text[$i] -ne "`n") { $i++ }
            if ($i -lt $Text.Length) { [void]$sb.Append($Text[$i]) }
            continue
        }
        if ($c -eq '/' -and $n -eq '*') {
            $i += 2
            while ($i + 1 -lt $Text.Length -and -not ($Text[$i] -eq '*' -and $Text[$i + 1] -eq '/')) { $i++ }
            $i++
            continue
        }
        [void]$sb.Append($c)
    }
    $sb.ToString()
}

function ConvertFrom-JsonLoose {
    param([string]$Raw)
    try {
        return $Raw | ConvertFrom-Json -AsHashtable
    } catch {
        $clean = Remove-JsonComments $Raw
        $clean = [regex]::Replace($clean, ',(\s*[}\]])', '$1')   # vírgulas sobrando
        return $clean | ConvertFrom-Json -AsHashtable
    }
}

function Merge-AppearanceInto {
    # Sobrescreve apenas as chaves presentes em $Fragment; preserva o resto.
    param([hashtable]$Target, [hashtable]$Fragment)

    if ($Fragment.ContainsKey('profiles') -and $Fragment['profiles'].ContainsKey('defaults')) {
        if (-not $Target.ContainsKey('profiles') -or $null -eq $Target['profiles']) { $Target['profiles'] = @{} }
        if (-not $Target['profiles'].ContainsKey('defaults') -or $null -eq $Target['profiles']['defaults']) {
            $Target['profiles']['defaults'] = @{}
        }
        foreach ($k in $Fragment['profiles']['defaults'].Keys) {
            $Target['profiles']['defaults'][$k] = $Fragment['profiles']['defaults'][$k]
        }
    }

    foreach ($arrKey in @('schemes', 'themes')) {
        if (-not $Fragment.ContainsKey($arrKey)) { continue }
        $byName = [ordered]@{}
        if ($Target.ContainsKey($arrKey) -and $Target[$arrKey]) {
            foreach ($item in @($Target[$arrKey])) {
                $name = if (($item -is [System.Collections.IDictionary]) -and $item.Contains('name')) { $item['name'] } else { $null }
                if ($name) { $byName[$name] = $item } else { $byName[[guid]::NewGuid().ToString()] = $item }
            }
        }
        foreach ($item in @($Fragment[$arrKey])) {
            if (($item -is [System.Collections.IDictionary]) -and $item.Contains('name')) { $byName[$item['name']] = $item }
        }
        $Target[$arrKey] = @($byName.Values)
    }
}

if ($SkipTerminal) {
    Write-Warn "-SkipTerminal: personalização do Windows Terminal não aplicada"
} else {
    Write-Host ""
    Write-Step "Windows Terminal — personalização..."

    $AppearanceSrc = Join-Path $ScriptDir 'windows-terminal\appearance.json'
    $wtCandidates = @(
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json')
        (Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json')
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\settings.json')
    )
    $wtTargets = @($wtCandidates | Where-Object { Test-Path $_ })

    if (-not (Test-Path $AppearanceSrc)) {
        Write-Warn "appearance.json não encontrado — pulando."
    } elseif (-not $wtTargets) {
        Write-Warn "settings.json do Windows Terminal não encontrado."
        Write-Warn "Abra o Windows Terminal uma vez e rode:  .\install.ps1 -SkipInstall"
    } else {
        $apply = $true
        if (-not $Force) {
            $r = Read-Host "  Aplicar personalização do Windows Terminal? (S/n)"
            if ($r -in @('n', 'N', 'nao', 'não', 'no')) { $apply = $false }
        }
        if (-not $apply) {
            Write-Warn "Personalização do Windows Terminal ignorada."
        } else {
            $fragment = ConvertFrom-JsonLoose (Get-Content -Raw -Path $AppearanceSrc)
            if ($fragment.ContainsKey('_comment')) { $fragment.Remove('_comment') }
            foreach ($settingsPath in $wtTargets) {
                try {
                    $raw = Get-Content -Raw -Path $settingsPath
                    $settings = ConvertFrom-JsonLoose $raw
                    $bak = "$settingsPath.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
                    Copy-Item $settingsPath $bak -Force
                    Merge-AppearanceInto -Target $settings -Fragment $fragment
                    $settings | ConvertTo-Json -Depth 32 | Set-Content -Path $settingsPath -Encoding utf8
                    Write-Ok "Aplicado em $settingsPath"
                    Write-Ok "Backup: $bak"
                } catch {
                    Write-Warn "Falhou em $settingsPath : $($_.Exception.Message)"
                }
            }
        }
    }
}

# ─────────────────────────────────────────────────────────────────────
# 9. Resumo
# ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "  ══════════════════════════════════════════" -ForegroundColor DarkGray
Write-Host "  ✅ Instalação concluída!" -ForegroundColor Green
Write-Host ""
Write-Host "  Próximos passos:" -ForegroundColor Gray
Write-Host "    1. Feche e reabra o Windows Terminal (ou rode:  . `$PROFILE )" -ForegroundColor Gray
Write-Host "    2. Instale a Nerd Font usada pelo tema e confirme no terminal:" -ForegroundColor Gray
Write-Host "       winget install --id DEVCOM.FiraCodeNerdFont -e" -ForegroundColor DarkGray
Write-Host "       (o appearance.json já seleciona 'FiraCode Nerd Font Propo')" -ForegroundColor DarkGray
Write-Host ""
