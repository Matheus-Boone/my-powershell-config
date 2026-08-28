# ⚡ My PowerShell Config

Minha configuração personalizada do **PowerShell 7+** para Windows, otimizada para inicialização rápida.

> **Resultado:** tempo de carregamento reduzido de **~9 segundos** para **~500ms** 🚀

---

## ✨ Funcionalidades

| Recurso | Descrição |
|---------|-----------|
| 🎨 **Oh My Posh** | Tema [Catppuccin Mocha](https://catppuccin.com/) com cache local |
| 📖 **PSReadLine** | Histórico preditivo com ListView e autocomplete via Tab |
| 📂 **z** | Navegação rápida de diretórios por frequência |
| 🔍 **PSFzf** | Busca fuzzy integrada ao terminal (requer `fzf`) |
| 🎭 **Terminal-Icons** | Ícones para arquivos e pastas no terminal |
| 🏓 **Ping colorido** | Latência com cores: 🟢 ≤50ms · 🟡 ≤100ms · 🔴 >100ms |
| 🗺️ **Tracert colorido** | Trace route com destaque visual por status |
| 🧰 **Ferramentas de rede** | `Test-Port`/`tp`, `Port-Scan`, `dns`, `myip`, `ipinfo`, `flushdns` |
| 🪛 **Utilidades** | `open`, `reload`, `edit-profile`, `ff`, `diskusage`, `New-Password` |
| 🪟 **Windows Terminal** | Personalização visual (acrílico/blur, opacidade, fonte, esquema de cores, padding) versionada e aplicada por merge |

## 🚀 Otimizações de Performance

- **Tema local** — Oh My Posh carrega o tema do disco, sem requisição HTTP
- **Cache de init** — Script de inicialização pré-gerado (sem re-parsear a cada abertura)
- **Lazy-loading** — Módulos `z` e `PSFzf` carregam *após* o primeiro prompt via `OnIdle`
- **Sem Import-Module redundante** — PSReadLine já vem carregado no PowerShell 7+

---

## 📋 Pré-requisitos

Você só precisa disto manualmente; o resto o `install.ps1` resolve:

- **[PowerShell 7+](https://github.com/PowerShell/PowerShell)**
  ```powershell
  winget install --id Microsoft.PowerShell -e
  ```
- **[winget](https://learn.microsoft.com/windows/package-manager/winget/)** (já vem no Windows 11; no Windows 10 instale o *App Installer* pela Microsoft Store)
- **Git**
  ```powershell
  winget install --id Git.Git -e
  ```

O instalador cuida automaticamente de: **Oh My Posh**, **fzf**, os módulos **PSReadLine**, **z**, **PSFzf** e **Terminal-Icons**, e da **personalização do Windows Terminal**.

---

## 📦 Instalação do zero

> Abra o **PowerShell 7** (o app chama-se "PowerShell", ícone preto — **não** é o "Windows PowerShell" azul).

1. **Clone o repositório:**
   ```powershell
   git clone https://github.com/Matheus-Boone/my-powershell-config.git
   cd my-powershell-config
   ```

2. **Execute o instalador:**
   ```powershell
   .\install.ps1
   ```

   > Se aparecer erro de execução de script, rode antes:
   > ```powershell
   > Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
   > ```
   > (o próprio `install.ps1` também tenta ajustar isso).

   O script vai:
   - Validar que você está no PowerShell 7+ e ajustar a `ExecutionPolicy` do usuário
   - Instalar **Oh My Posh** e **fzf** via winget (se faltarem)
   - Instalar os módulos **PSReadLine**, **z**, **PSFzf**, **Terminal-Icons** (escopo `CurrentUser`)
   - Copiar o tema para `~\.config\ohmyposh\`
   - Gerar o cache de init do Oh My Posh
   - Instalar o perfil em `$PROFILE` (fazendo **backup** de um perfil já existente)
   - Aplicar a personalização do **Windows Terminal** no `settings.json` (merge, com **backup**)

3. **Instale a Nerd Font usada pelo tema** (necessário para os ícones):
   ```powershell
   winget install --id DEVCOM.FiraCodeNerdFont -e
   ```
   O `appearance.json` já seleciona **"FiraCode Nerd Font Propo"** no Windows Terminal — só reabra o terminal. Se preferir outra fonte, ajuste `windows-terminal/appearance.json` antes de rodar o instalador.

4. **Feche e reabra o Windows Terminal.** 🎉
   (ou, sem fechar: `. $PROFILE`)

### Opções do instalador

| Comando | Efeito |
|---------|--------|
| `.\install.ps1` | Instalação normal (pergunta antes de sobrescrever o perfil e antes de mexer no Windows Terminal) |
| `.\install.ps1 -Force` | Não pergunta nada; sempre gera backup antes de sobrescrever |
| `.\install.ps1 -SkipInstall` | Só copia tema + cache + perfil + Windows Terminal; não instala dependências |
| `.\install.ps1 -SkipTerminal` | Não toca no `settings.json` do Windows Terminal |

---

## 🔧 Instalação manual das dependências (fallback)

Se não tiver winget ou preferir fazer à mão:

```powershell
# Ferramentas externas
winget install --id JanDeDobbeleer.OhMyPosh -e
winget install --id junegunn.fzf -e

# Módulos
Install-Module PSReadLine     -Scope CurrentUser -Force -SkipPublisherCheck
Install-Module z              -Scope CurrentUser -Force
Install-Module PSFzf          -Scope CurrentUser -Force
Install-Module Terminal-Icons -Scope CurrentUser -Force
```

Depois rode `.\install.ps1 -SkipInstall`.

---

## 🪟 Personalização do Windows Terminal

As chaves de aparência ficam versionadas em [`windows-terminal/appearance.json`](windows-terminal/appearance.json):

| Chave | Valor |
|-------|-------|
| `profiles.defaults.useAcrylic` | `true` (blur / acrílico) |
| `profiles.defaults.opacity` | `76` |
| `profiles.defaults.colorScheme` | `Catppuccin Mocha` |
| `profiles.defaults.font` | `FiraCode Nerd Font Propo`, tamanho `13`, peso `normal` |
| `profiles.defaults.padding` | `8` |
| `profiles.defaults.intenseTextStyle` | `bold` |
| `profiles.defaults.experimental.retroTerminalEffect` | `false` |
| `schemes` | esquemas `Catppuccin Mocha` e `Dracula` |

**Como o merge funciona** (`install.ps1`, etapa 8):

- Localiza o `settings.json` do Windows Terminal (Store, Preview ou versão *unpackaged*).
- Faz **backup**: `settings.json.bak-<data>`.
- Sobrescreve **apenas** as chaves acima. `defaultProfile`, lista de perfis, `keybindings`, `actions` e qualquer outra config sua são preservados.
- `schemes` é mesclado **por nome**: os seus continuam, os do repo são adicionados/atualizados.
- É **idempotente** — rodar de novo não duplica nada.
- Comentários (`//`, `/* */`) do `settings.json` são removidos na regravação (o Windows Terminal não usa comentários por padrão).

Para mudar fonte, opacidade, cores etc. em todas as máquinas: edite `windows-terminal/appearance.json`, faça commit e rode `.\install.ps1 -SkipInstall` onde quiser aplicar.

Pulá-lo: `.\install.ps1 -SkipTerminal`.

---

## 🔄 Atualizando

```powershell
cd my-powershell-config
git pull
.\install.ps1 -Force
```

Para regenerar só o cache do Oh My Posh (ex.: depois de editar o tema):
```powershell
oh-my-posh init pwsh --config "$env:USERPROFILE\.config\ohmyposh\catppuccin_mocha.omp.json" --print |
    Set-Content "$env:USERPROFILE\.config\ohmyposh\omp_init.ps1" -Encoding utf8
```

---

## 🩹 Solução de problemas

| Sintoma | Causa / correção |
|---------|------------------|
| `install.ps1 ... não pode ser carregado porque a execução de scripts foi desabilitada` | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| Ícones aparecem como quadrados/`?` | Nerd Font não instalada ou não selecionada no terminal (passo 3) |
| Prompt sem tema após instalar | Você abriu o **Windows PowerShell** (5.1). Use o **PowerShell 7** |
| `oh-my-posh : O termo não é reconhecido` logo após instalar | PATH ainda não atualizado; feche o terminal, reabra e rode `.\install.ps1 -SkipInstall` |
| `PSFzf` não completa com fuzzy | Falta o binário `fzf` no PATH (`winget install junegunn.fzf`) |
| Quero meu perfil antigo de volta | Está salvo como `Microsoft.PowerShell_profile.ps1.bak-<data>` ao lado do `$PROFILE` |
| Aparência do Windows Terminal não mudou | Reabra **todas** as janelas do terminal; confirme que o `settings.json` foi salvo (veja o `.bak-<data>` ao lado dele) |
| Quero o `settings.json` antigo do Windows Terminal | Restaure o `settings.json.bak-<data>` gerado na pasta `...\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\` |
| `settings.json` do Windows Terminal não encontrado | Abra o Windows Terminal ao menos uma vez e rode `.\install.ps1 -SkipInstall` |

Ver caminho do perfil e se está carregando:
```powershell
$PROFILE            # caminho do arquivo
Test-Path $PROFILE  # deve dar True após instalar
```

---

## 📁 Estrutura

```
my-powershell-config/
├── Microsoft.PowerShell_profile.ps1  # Perfil principal
├── ohmyposh/
│   └── catppuccin_mocha.omp.json     # Tema Oh My Posh
├── windows-terminal/
│   └── appearance.json               # Personalização visual do Windows Terminal
├── install.ps1                        # Instalador (do zero)
├── .gitignore
└── README.md
```

---

## 🗑️ Desinstalar

```powershell
# Restaura backup mais recente (se houver) ou remove o perfil
$bak = Get-ChildItem "$(Split-Path $PROFILE)\Microsoft.PowerShell_profile.ps1.bak-*" -EA SilentlyContinue |
       Sort-Object Name -Descending | Select-Object -First 1
if ($bak) { Copy-Item $bak.FullName $PROFILE -Force } else { Remove-Item $PROFILE -Force }

Remove-Item "$env:USERPROFILE\.config\ohmyposh" -Recurse -Force

# Restaura o settings.json do Windows Terminal a partir do backup mais recente
$wt = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
$wtBak = Get-ChildItem "$wt.bak-*" -EA SilentlyContinue | Sort-Object Name -Descending | Select-Object -First 1
if ($wtBak) { Copy-Item $wtBak.FullName $wt -Force }

# Opcional: remover ferramentas/módulos
Uninstall-Module z, PSFzf, Terminal-Icons -AllVersions
winget uninstall --id JanDeDobbeleer.OhMyPosh -e
winget uninstall --id junegunn.fzf -e
```

---

## 📄 Licença

MIT
