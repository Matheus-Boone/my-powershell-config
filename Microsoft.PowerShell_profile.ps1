# ╔══════════════════════════════════════════════════════════════════════╗
# ║  PowerShell 7+ Profile — Matheus Boone                             ║
# ║  Otimizado para inicialização rápida (~500ms)                      ║
# ╚══════════════════════════════════════════════════════════════════════╝

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
. "$env:USERPROFILE\.config\ohmyposh\omp_init.ps1"

# --- Módulos deferidos (carregam após o primeiro prompt para não travar a inicialização) ---
$null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
    Import-Module z -Global
    Import-Module PSFzf -Global
    Set-PsFzfOption -TabExpansion
    Import-Module Terminal-Icons -Global
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

# --- Wrapper para Tracert Colorido ---
function tracert {
    & tracert.exe $args | ForEach-Object {
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
