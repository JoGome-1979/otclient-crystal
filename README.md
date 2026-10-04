<h1>
  <img src="https://crystalgames.com.br/plugins/theme-canary/themes/canary/images/header/tibia-logo-artwork-top.gif" width="32" alt="logo"/>
  Crystal Ot Client - Redemption
</h1>

[![Discord Shield](https://discordapp.com/api/guilds/888062548082061433/widget.png?style=shield)](https://discord.gg/tUjTBZzMCy)
[![CI](https://github.com/opentibiabr/otclient/actions/workflows/ci.yml/badge.svg)](https://github.com/opentibiabr/otclient/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

---

## <a id="table-of-contents"></a>📋 Sumário
1. ![Logo](https://raw.githubusercontent.com/JoGome-1979/otclient-crystal/refs/heads/main/src/otcicon.ico)  [O que é o OTClient?](#what-is-otclient)
2. 🚀 [Recursos](#features)
3. <img height="16" src="https://raw.githubusercontent.com/github/explore/80688e429a7d4ef2fca1e82350fe8e3517d3494d/topics/android/android.png"/> [O Projeto Mobile](#the-mobile-project)
4. 🔨 [Compilação](#compiling)
5. 🐳 [Docker](#docker)
6. 🩺 [Precisa de ajuda?](#need-help)
7. 📑 [Bugs](#bugs)
8. ❤️ [Roadmap](#roadmap)
9. 💯 [Protocolo de Suporte](#support-protocol)
10. ©️ [Licença](#license)
11. ❤️ [Contribuidores](#contributors)
12. 📦 [Instalação Automática de Assets do Cliente](docs/client-assets-auto-install.md)

---

## <a id="what-is-otclient"></a>![Logo](https://raw.githubusercontent.com/mehah/otclient/main/src/otcicon.ico) O que é o OTClient?
O OTClient é um cliente alternativo para Tibia para uso com OTServ. Ele tem como objetivo ser completo e flexível:

- **Script em LUA** para toda a funcionalidade da interface do jogo
- **Sintaxe semelhante a CSS** para o design da interface
- **Sistema modular**: cada funcionalidade é um módulo separado, permitindo fácil personalização
- Usuários podem criar novos mods e estender a interface
- Escrito em **C++20** e fortemente scriptado em **LUA**

Para se conectar a um servidor, você pode criar seu próprio com **theforgottenserver** ou **canary**.

> [!NOTE]
> Baseado em [edubart/otclient](https://github.com/edubart/otclient) • Rev: [2.760](https://github.com/edubart/otclient/commit/fc39ee4adba8e780a2820bfda66fc942d74cedf4)

---

## <a id="features"></a>🚀 Recursos

Além da flexibilidade com scripts, o OTClient vem com muitos recursos que permitem inovação do lado do cliente em OTServ: **sistema de som**, **efeitos gráficos com shaders**, **módulos/add-ons**, **animação de sprites**, entre outros.

### ⚡ Desempenho & Motor
<details>
  <summary>🖼️ Draw Render (demonstração de otimização)</summary>

  https://github.com/user-attachments/assets/fe5f1d7f-7195-4d65-bca6-c2b5d62d3890
</details>

<details>
  <summary>📦 Carregamento Assíncrono de Texturas</summary>

- **Descrição**: com isso, o arquivo spr não é armazenado em cache, consequentemente, menos RAM é consumida.
- **Vídeo**:

  https://github.com/kokekanon/otclient.readme/assets/114332266/f3b7916a-d6ed-46f5-b516-30421de4616d
</details>

<details>
  <summary>🧵 Multithreading</summary>

**Thread principal**
- Som
- Partículas
- Carregar Texturas (arquivos)
- Eventos da janela (teclado, mouse, ...)
- Desenhar textura

**Thread 2**
- Conexão
- Eventos (g_dispatcher)
- Coletar informações sobre o que será desenhado no Mapa

**Thread 3**
- Coletar informações sobre o que será desenhado na UI

**Imagem:**  
![multinucleo](https://github.com/kokekanon/otclient.readme/assets/114332266/95fb15ac-553f-4eca-937f-8f22-b51844801df4)
</details>

<details>
  <summary>🧹 Coleta de Lixo</summary>

**Descrição (1):**
