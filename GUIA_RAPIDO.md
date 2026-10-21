# 🚀 AetherControl — Guia Rápido de Instalação e Utilização

Bem-vindo ao **AetherControl**, um software moderno, minimalista e open-source para monitorização de hardware e controlo inteligente de ventoinhas e sistemas de refrigeração líquida (AIO).

---

## ⚡ 1. Instalação (Escolha a forma mais fácil)

### Opção A: Instalação Automática num Único Comando (Recomendada)
Abra o **PowerShell** no Windows e cole o comando seguinte, premindo `Enter`:

```powershell
irm https://raw.githubusercontent.com/henriquelaia/AetherControl/main/get.ps1 | iex
```

* O que este comando faz automaticamente:
  1. Descarrega os ficheiros da aplicação de forma segura.
  2. Cria o atalho oficial com o ícone no seu **Ambiente de Trabalho**.
  3. Cria o atalho no **Menu Iniciar** do Windows.
  4. Deteta os componentes do seu computador e abre a aplicação de imediato.

---

### Opção B: Download Manual do Arquivo ZIP
Se preferir não usar o terminal para instalar:
1. No topo da página do GitHub, clique no botão verde **`Code`** e selecione **`Download ZIP`**.
2. Extraia o ficheiro ZIP para uma pasta à sua escolha (por exemplo, na pasta `Documentos` ou `Programas`).
3. Dê duplo clique no ficheiro:
   ```text
   Criar-Atalho-Ambiente-Trabalho.bat
   ```
   *(ou `Create-Desktop-Shortcut.bat` se o seu Windows estiver em inglês)*.
4. O atalho é criado no seu **Ambiente de Trabalho** e a aplicação pergunta se deseja abrir logo o programa.

---

## 🖥️ 2. Como Abrir a Aplicação no Dia a Dia

Depois de instalado, tem 3 formas simples de abrir o AetherControl:

1. **Pelo Ambiente de Trabalho:** Duplo clique no ícone **`AetherControl Studio`**.
2. **Pelo Menu Iniciar:** Pressione a tecla `Windows` do teclado, escreva **`AetherControl`** e prima `Enter`.
3. **Pela Pasta do Programa:** Dê duplo clique no ficheiro **`Launch-AetherControl.bat`**.

> [!TIP]
> A aplicação abre numa janela elegante sem moldura do browser (estilo app nativa) consumindo apenas cerca de **15 MB de RAM**.

---

## 🎛️ 3. Como Usar as Funcionalidades

### 🌪️ Curva de Ventoinhas Personalizada
* **Ajustar Velocidades:** Clique e arraste os 5 pontos (`P1` a `P5`) na curva azul para definir a percentagem de velocidade das ventoinhas em função da temperatura (`20°C` a `100°C`).
* **Botão "Opções":** Permite definir o sensor de referência (processador CPU, placa gráfica GPU, água do AIO ou o componente mais quente), ativar histerese (suavização para as ventoinhas não acelerarem bruscamente) ou fixar uma velocidade manual.
* **Perfis Prontos:** Use os botões no topo para alternar rapidamente entre os modos **Silencioso**, **Equilibrado**, **Desempenho** ou **Máximo**.

### 🔍 Identificar as Ventoinhas Físicas
Tem dúvidas sobre a que ventoinha física corresponde o conector `CPU_FAN1` ou `SYS_FAN1` na sua caixa?
* No cartão de ventoinhas, clique no botão **`Testar`** ao lado do canal.
* Essa ventoinha específica acelera a 100% durante **3.5 segundos** e volta à velocidade normal, permitindo-lhe ouvir e ver exatamente onde está instalada.

### 🧊 Refrigeração Líquida (AIO) e Bomba
* O cartão superior dedicado mostra a **Temperatura da Água**, a rotação da **Bomba (`RPM`)** e a saturação térmica do radiador.
* **Modos da Bomba:** Escolha entre **Calmo (`70%`)**, **Normal (`85%`)** e **Máx (`100%`)**.
* **Purgar Bolhas:** Carregue neste botão se ouvir ruído de líquido no bloco. A bomba acelera e desacelera durante 15 segundos para expelir micro-bolhas de ar para o radiador.

### 🎮 Gémeo Digital 3D (CAD Sólido)
* No painel direito, aceda à aba **Gémeo 3D** para ver uma representação em tempo real do seu computador com iluminação térmica reativa.
* Clique no botão **`Expandir`** para abrir o modo de inspeção ampla:
  * **Arrastar com o rato:** Roda o ângulo de visualização 3D.
  * **Roda do rato:** Aproxima ou afasta o zoom (`0.9x` a `3.8x`).
  * **Repor Câmara:** Volta ao ângulo original de visualização.

### 🌐 Perfis da Comunidade e Plugins
* Na aba **Comunidade**, pode carregar curvas testadas por outros utilizadores (*HydroLoop 360mm*, *Whisper SFF*, *Esports 240Hz*, *Workstation 24/7*) com um único clique.
* Ative ou desative plugins modulares com um clique (registo de temperaturas em CSV, curvas de histerese avançadas, etc.).

### ⌨️ Menu de Comandos Rápidos (`Ctrl + K`)
* Pressione **`Ctrl + K`** em qualquer ecrã para abrir a barra de comandos rápidos e executar qualquer ação sem tirar as mãos do teclado.

---

## 🛑 4. Como Fechar ou Parar o Serviço

* **Pela Aplicação:** Clique no botão vermelho **`Sair`** no canto superior direito.
* **Por Ficheiro:** Dê duplo clique no ficheiro **`Stop-AetherControl.bat`** na pasta da aplicação.

---

## ❓ 5. Dúvidas Frequentes e Resolução de Problemas

### O Windows SmartScreen mostra a mensagem "O Windows protegeu o seu PC"?
Isto acontece habitualmente em ferramentas open-source novas que ainda não têm milhares de downloads na Microsoft:
1. Clique em **"Mais informações"**.
2. Clique no botão **"Executar de qualquer forma"**.
3. O código do AetherControl é 100% aberto e transparente, podendo ser auditado livremente neste repositório.

### Algumas ventoinhas da Motherboard não aparecem na lista?
Os chips de controlo Super I/O da placa principal (ITE, Nuvoton) requerem permissões diretas de leitura de portas de hardware no Windows:
* Clique com o botão direito no atalho **`AetherControl Studio`** ou em `Launch-AetherControl.bat` e escolha **"Executar como Administrador"**.

### As minhas definições ficam guardadas quando fecho o computador?
Sim. Todas as curvas, pontos personalizados, preferências de idioma e tema são automaticamente guardados no ficheiro seguro `%LOCALAPPDATA%\AetherControl\settings.json`.
