# AetherControl — Guia do Utilizador (PT-PT) & User Guide (EN)

---

## 🇵🇹 Parte 1: Guia Completo em Português (PT-PT)

### 1. Instalação num Único Comando
Abra o **PowerShell** no Windows 10 ou Windows 11 e execute:
```powershell
irm https://raw.githubusercontent.com/henriquelaia/AetherControl/main/get.ps1 | iex
```
- **A partir do Ambiente de Trabalho:** Clique duas vezes no atalho **`AetherControl Studio`** criado automaticamente.
- **A partir da Pasta do Projeto:** Execute [`Launch-AetherControl.bat`](../Launch-AetherControl.bat) ou [`Install-AetherControl.ps1`](../Install-AetherControl.ps1).
- **Alternar Modo Claro / Escuro:** Clique no botão **☀️ / 🌙** no topo direito para alternar entre o modo claro e o modo escuro.
- **Como Parar o Serviço:** Clique (ou mantenha premido) no botão vermelho **`Sair`** no canto superior direito, ou execute [`Stop-AetherControl.bat`](../Stop-AetherControl.bat).

### 2. Deteção Automática de Hardware
- O **AetherControl** analisa automaticamente o Processador, a Placa Gráfica, a Motherboard, a Memória RAM e o sistema de arrefecimento do PC onde é instalado.
- Clique no botão com o nome do seu PC no canto superior esquerdo para abrir a janela **Componentes do Seu Computador** e atualizar a leitura a qualquer momento.

### 3. Sistema de Água (AIO) & Bomba
- O cartão dedicado **Sistema de Água (AIO)** no topo mostra em tempo real a **Temperatura da Água (`°C`)**, a **Velocidade da Bomba (`RPM`)**, a diferença para a temperatura ambiente e a **Saturação Térmica da Água (`%`)**.
- **Modos da Bomba:** Alterne entre **Calmo (`70%`)**, **Normal (`85%`)** e **Máx (`100%`)**.
- **Guiar pela água:** Ative o interruptor para controlar as ventoinhas pela temperatura do líquido em vez dos picos rápidos do processador.
- **Purgar Bolhas:** Oscila a velocidade da bomba entre `60%` e `100%` durante 15 segundos para libertar micro-bolhas de ar do bloco.

### 4. Curva de Velocidade das Ventoinhas
- **Arrastar Pontos (`P1`–`P5`):** Clique e arraste qualquer um dos 5 círculos na curva para ajustar a velocidade das ventoinhas (`% PWM`) em função da temperatura (`20°C–100°C`).
- **Faixa de Coordenadas (`P1` a `P5`):** Abaixo do gráfico encontra os valores exatos de cada ponto (`°C · %`).
- **Botão `Opções`:** Clique em **`Opções`** no topo do gráfico para escolher o sensor de referência (*Mais Quente*, *Temperatura da Água*, *Processador* ou *Placa Gráfica*), ajustar a suavização (*histerese*), evitar a paragem das ventoinhas da gráfica (*Zero-RPM*) ou definir uma velocidade fixa.

### 5. Atalhos de Teclado (`Ctrl + K`)
- Pressione **`Ctrl + K`** em qualquer momento para abrir os **Comandos Rápidos** e mudar de modo, alternar tema claro/escuro, purgar bolhas da bomba ou mudar o idioma (`PT` / `EN`).

---

## 🇬🇧 Part 2: Complete User Guide (English)

### 1. One-Command Installation
Open **PowerShell** on Windows 10 or Windows 11 and run:
```powershell
irm https://raw.githubusercontent.com/henriquelaia/AetherControl/main/get.ps1 | iex
```
- **From Desktop:** Double-click the **`AetherControl Studio`** shortcut on your Windows Desktop.
- **From Repository Folder:** Double-click [`Launch-AetherControl.bat`](../Launch-AetherControl.bat) or run [`Install-AetherControl.ps1`](../Install-AetherControl.ps1).
- **Light / Dark Mode:** Click the **☀️ / 🌙** button in the top-right header to switch between Light Mode and Dark Mode.
- **Stopping the Service:** Click or hold the red **`Quit`** button in the top-right header, or run [`Stop-AetherControl.bat`](../Stop-AetherControl.bat).

### 2. Automatic Hardware Discovery
- AetherControl automatically detects your CPU, GPU, Motherboard Super I/O controller, RAM, and Cooling Loop on startup.
- Click the hardware chip in the top-left navigation bar at any time to inspect your detected hardware components or trigger a refresh.

### 3. Water System (AIO) Card
- Displays live **Coolant Temperature (`°C`)**, **Pump Speed (`RPM`)**, **Ambient Delta (`+°C`)**, and **Water Thermal Saturation (`%`)** directly on the main dashboard.
- **Pump Modes:** Switch between **Quiet (`70%`)**, **Normal (`85%`)**, and **Max (`100%`)**.
- **Sync to water:** Guides radiator fan speeds using liquid temperature for smoother acoustics.
- **Purge Bubbles:** Cycles the pump between `60%` and `100%` for 15 seconds to clear trapped air pockets.

### 4. Fan Speed Curve & Quick Commands (`Ctrl + K`)
- Drag any of the 5 control points (`P1`–`P5`) along the curve to customize fan speeds across temperatures, and click **`Options`** to configure smoothing, sensor source, or fixed fan speeds.
- Press **`Ctrl + K`** anywhere to open the quick command launcher.
