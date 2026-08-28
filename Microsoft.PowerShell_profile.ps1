# --- Meus Atalhos ---
Set-Alias -Name ll -Value Get-ChildItem

# --- Navegação rápida de diretórios ---
function .. { Set-Location .. }

Set-Alias cc  Clear-Host

# --- Configuração do PSReadLine (já carregado automaticamente no PowerShell 7+) ---
# Ativa o histórico visual (estilo peixe/zsh)
Set-PSReadLineOption -PredictionSource History
Set-PSReadLineOption -PredictionViewStyle ListView
# Atalho para aceitar a sugestão com a tecla TAB
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

# --- Oh My Posh (cache do init — regenerar com o comando abaixo ao atualizar) ---
# Regenerar cache: oh-my-posh init pwsh --config "$env:USERPROFILE\.config\ohmyposh\catppuccin_mocha.omp.json" --print | Set-Content "$env:USERPROFILE\.config\ohmyposh\omp_init.ps1"
$env:POSH_THEME = "$env:USERPROFILE\.config\ohmyposh\catppuccin_mocha.omp.json"
$__ompInit = "$env:USERPROFILE\.config\ohmyposh\omp_init.ps1"
if (Test-Path $__ompInit) {
    . $__ompInit
} elseif (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    # Fallback: sem cache, inicializa ao vivo (mais lento). Rode install.ps1 para gerar o cache.
    oh-my-posh init pwsh --config $env:POSH_THEME | Invoke-Expression
} else {
    Write-Host "  ⚠ Oh My Posh não instalado — rode install.ps1" -ForegroundColor Yellow
}
Remove-Variable __ompInit -ErrorAction SilentlyContinue

# --- Módulos deferidos (carregam após o primeiro prompt para não travar a inicialização) ---
$null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
    if (Get-Module -ListAvailable -Name z)     { Import-Module z -Global }
    if (Get-Module -ListAvailable -Name PSFzf) {
        Import-Module PSFzf -Global
        Set-PsFzfOption -TabExpansion
    }
}

# O Terminal-Icons precisa ser importado no escopo principal para que a formatação visual funcione
if (Get-Module -ListAvailable -Name Terminal-Icons) {
    Import-Module Terminal-Icons
}

# --- Wrapper para Ping (Apenas IP e Tempo Coloridos) ---
function ping {
    # Definindo os códigos de cor ANSI
    $ESC = [char]27
    $Reset = "$ESC[0m"
    $HostColor = "$ESC[36m" # 36m = Ciano (Cor do IP)
    
    & ping.exe $args | ForEach-Object {
        $line = $_
        
        # Falhas continuam destacadas em vermelho
        if ($line -match "(?i)esgotado|falha|inacessível|timed out|unreachable") {
            Write-Host $line -ForegroundColor Red
        } 
        # Captura exatamente as partes da linha de resposta
        elseif ($line -match "(?i)(Resposta de|Reply from) (.*?): (.*?)((tempo|time)[=|<](\d+)ms)(.*)") {
            $prefix  = $Matches[1] # "Resposta de"
            $ip      = $Matches[2] # "192.64.151.235"
            $middle  = $Matches[3] # "bytes=32 "
            $timeStr = $Matches[4] # "tempo=166ms"
            $timeVal = [int]$Matches[6] # "166" (para o cálculo)
            $end     = $Matches[7] # " TTL=43"
            
            # Lógica de cor da latência
            if ($timeVal -le 50) { 
                $TimeColor = "$ESC[32m" # 32m = Verde
            }
            elseif ($timeVal -le 100) { 
                $TimeColor = "$ESC[33m" # 33m = Amarelo
            }
            else { 
                $TimeColor = "$ESC[31m" # 31m = Vermelho
            }
            
            # Remonta a linha injetando a cor apenas no IP e no Tempo
            $coloredLine = "$prefix ${HostColor}${ip}:${Reset} ${middle}${TimeColor}${timeStr}${Reset}${end}"
            Write-Host $coloredLine
        } 
        # Linhas de estatísticas e cabeçalhos passam direto sem alteração de cor
        else {
            Write-Host $line
        }
    }
}

# --- Wrapper para Tracert Colorido (Mais rápido por padrão) ---
function tracert {
    & tracert.exe -d -w 500 $args | ForEach-Object {
        # Asteriscos de perda de pacote ou timeout
        if ($_ -match "\* {8}\* {8}\*|esgotado|timed out") {
            Write-Host $_ -ForegroundColor Red
        } 
        # Linhas com resposta de latência (contém 'ms')
        elseif ($_ -match "ms") {
            Write-Host $_ -ForegroundColor Green
        } 
        # Cabeçalho e rodapé
        else {
            Write-Host $_ -ForegroundColor Cyan
        }
    }
}

# ── FERRAMENTAS DE REDE ──────────────────────────────────────────────

# Teste de porta TCP (substitui telnet)
function Test-Port {
    param(
        [Parameter(Mandatory, Position=0)][string]$Target,
        [Parameter(Mandatory, Position=1)][int]$Port,
        [int]$Timeout = 2000
    )
    $tcp = New-Object System.Net.Sockets.TcpClient
    try {
        $result = $tcp.BeginConnect($Target, $Port, $null, $null)
        $success = $result.AsyncWaitHandle.WaitOne($Timeout)
        if ($success -and $tcp.Connected) {
            Write-Host "  ✓ ${Target}:${Port} — ABERTA" -ForegroundColor Green
        } else {
            Write-Host "  ✗ ${Target}:${Port} — FECHADA/TIMEOUT" -ForegroundColor Red
        }
    } catch {
        Write-Host "  ✗ ${Target}:${Port} — ERRO: $_" -ForegroundColor Red
    } finally { $tcp.Dispose() }
}
Set-Alias tp Test-Port

# Scan rápido de portas comuns
function Port-Scan {
    param([Parameter(Mandatory, Position=0)][string]$Target)
    $ports = @(21,22,23,25,53,80,443,3306,3389,5432,6379,8080,8443,27017)
    Write-Host "`n  🔍 Scanning $Target..." -ForegroundColor Cyan
    foreach ($p in $ports) { Test-Port -Target $Target -Port $p -Timeout 1000 }
    Write-Host ""
}

# DNS Lookup rápido
function dns {
    param(
        [Parameter(Mandatory, Position=0)][string]$Name,
        [Parameter(Position=1)][string]$Type = "A"
    )
    Resolve-DnsName -Name $Name -Type $Type | Format-Table Name, Type, TTL, IPAddress, NameHost -AutoSize
}

# Meu IP público
function myip {
    try {
        $ip = (Invoke-RestMethod -Uri "https://api.ipify.org?format=json" -TimeoutSec 3).ip
        Write-Host "  🌍 IP Público: $ip" -ForegroundColor Cyan
    } catch { Write-Host "  ✗ Sem conexão" -ForegroundColor Red }
}

# Whois/info de IP
function ipinfo {
    param([Parameter(Mandatory, Position=0)][string]$IP)
    Invoke-RestMethod "https://ipinfo.io/$IP/json" | Format-List ip, hostname, city, region, country, org
}

# Flush DNS
function flushdns {
    Clear-DnsClientCache
    Write-Host "  ✓ Cache DNS limpo" -ForegroundColor Green
}

# ── UTILIDADES ────────────────────────────────────────────────────────

# Abre diretório atual no Explorer
function open { explorer.exe $(if ($args) { $args } else { "." }) }

# Edita o perfil rapidamente
function edit-profile { code $PROFILE }

# Recarrega o perfil sem fechar o terminal
function reload { . $PROFILE; Write-Host "  ✓ Perfil recarregado" -ForegroundColor Green }

# Busca arquivo por nome (recursivo)
function ff {
    param([Parameter(Mandatory, Position=0)][string]$Pattern)
    Get-ChildItem -Recurse -Filter "*$Pattern*" -ErrorAction SilentlyContinue |
        Select-Object FullName, Length |
        Format-Table -AutoSize
}

# Uso de disco por pasta
function diskusage {
    Get-ChildItem -Directory | ForEach-Object {
        $size = (Get-ChildItem $_.FullName -Recurse -File -ErrorAction SilentlyContinue |
                 Measure-Object Length -Sum).Sum
        [PSCustomObject]@{
            Pasta   = $_.Name
            Tamanho = if ($size -gt 1GB) { "$([math]::Round($size/1GB,2)) GB" }
                      elseif ($size -gt 1MB) { "$([math]::Round($size/1MB,2)) MB" }
                      elseif ($size) { "$([math]::Round($size/1KB,2)) KB" }
                      else { "0 KB" }
            Bytes   = [long]$size
        }
    } | Sort-Object Bytes -Descending | Select-Object Pasta, Tamanho | Format-Table -AutoSize
}

# Gerador de senha (copia automaticamente pro clipboard)
function New-Password {
    param([int]$Length = 20)
    $chars = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ0123456789!@#$%&*'
    $pw = -join (1..$Length | ForEach-Object { $chars[(Get-Random -Maximum $chars.Length)] })
    $pw | Set-Clipboard
    Write-Host "  🔐 Senha ($Length chars): $pw" -ForegroundColor Cyan
    Write-Host "  ✓ Copiada para o clipboard" -ForegroundColor Green
}
# Atalho MTR para tracert
Set-Alias -Name mtr -Value tracert
