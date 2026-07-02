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
| 🔍 **PSFzf** | Busca fuzzy integrada ao terminal |
| 🎭 **Terminal-Icons** | Ícones para arquivos e pastas no terminal |
| 🏓 **Ping colorido** | Latência com cores: 🟢 ≤50ms · 🟡 ≤100ms · 🔴 >100ms |
| 🗺️ **Tracert colorido** | Trace route com destaque visual por status |

## 🚀 Otimizações de Performance

- **Tema local** — Oh My Posh carrega o tema do disco, sem requisição HTTP
- **Cache de init** — Script de inicialização pré-gerado (sem re-parsear a cada abertura)
- **Lazy-loading** — Módulos `z`, `PSFzf` e `Terminal-Icons` carregam *após* o primeiro prompt via `OnIdle`
- **Sem Import-Module redundante** — PSReadLine já vem carregado no PowerShell 7+

## 📋 Pré-requisitos

- [PowerShell 7+](https://github.com/PowerShell/PowerShell)
- [Oh My Posh](https://ohmyposh.dev/)
- Uma [Nerd Font](https://www.nerdfonts.com/) instalada no terminal

**Módulos PowerShell:**
```powershell
Install-Module -Name PSReadLine -Force -SkipPublisherCheck
Install-Module -Name z -Force
Install-Module -Name PSFzf -Force
Install-Module -Name Terminal-Icons -Force
```

## 📦 Instalação

1. **Clone o repositório:**
   ```powershell
   git clone https://github.com/Matheus-Boone/my-powershell-config.git
   cd my-powershell-config
   ```

2. **Execute o script de instalação:**
   ```powershell
   .\install.ps1
   ```

   Isso irá:
   - Copiar o tema Oh My Posh para `~\.config\ohmyposh\`
   - Gerar o cache de inicialização do Oh My Posh
   - Instalar o perfil em `$PROFILE`

3. **Reabra o terminal** e aproveite! 🎉

## 📁 Estrutura

```
my-powershell-config/
├── Microsoft.PowerShell_profile.ps1  # Perfil principal
├── ohmyposh/
│   └── catppuccin_mocha.omp.json     # Tema Oh My Posh
├── install.ps1                        # Script de instalação
├── .gitignore
└── README.md
```

## 📄 Licença

MIT
