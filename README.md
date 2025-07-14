# 🔍 redscan-toolkit

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/Shell-Bash-blue.svg?logo=gnu-bash)](https://www.gnu.org/software/bash/)
[![RustScan](https://img.shields.io/badge/Scanner-RustScan-orange?logo=rust)](https://github.com/RustScan/RustScan)
[![Nmap](https://img.shields.io/badge/Scanner-Nmap-red?logo=nmap)](https://nmap.org/)
[![Status](https://img.shields.io/badge/Status-Stable-brightgreen.svg)](#)

Script Bash para automação de varredura de portas utilizando Rustscan e Nmap.

> Ferramenta ideal para profissionais de segurança e pentesters que buscam identificar rapidamente portas abertas e realizar escaneamentos detalhados.

---

## ⚙️ Requisitos

- Bash (versão 4.x ou superior)
- [Rustscan](https://github.com/RustScan/RustScan)
- [Nmap](https://nmap.org/)
- Permissões de superusuário (`sudo`) para execução do Nmap

---

## 📦 Instalação

```bash
git clone https://github.com/GabrielMartorelli/redscan.git
cd redscan
chmod +x portas.sh
```

## 🚀 Uso
Execute com privilégios de root:
```bash
sudo ./portas.sh
```
## Funcionalidades:
 - Solicita o endereço IP do alvo para escaneamento
 - Realiza varredura com Rustscan nas portas 1 a 65535
 - Aguarda 20 segundos para evitar conflitos entre ferramentas
 - Permite selecionar opções avançadas do Nmap:
    - Scan SYN (-sS)
    - Ignorar descoberta de host (-Pn)
    - Script de coleta de banners (--script=banner)
 - Executa Nmap com base nas portas abertas detectadas pelo Rustscan
 - Salva os resultados em arquivos:
    - Ports.txt: lista de portas abertas encontradas
    - allPorts.txt: relatório completo do Nmap

## 📁 Exemplo de execução:
```text
[*] Diretório atual onde o script está rodando: /home/user/redscan
Digite o IP alvo: 192.168.1.100
[*] Rodando Rustscan no IP 192.168.1.100...
[*] Portas abertas encontradas (salvas em Ports.txt):
Open 192.168.1.100:22
Open 192.168.1.100:80
Deseja usar a flag -sS (SYN scan) no Nmap? (y/n): y
Deseja usar a flag -Pn no Nmap? (y/n): y
Deseja usar o script de banner grab (--script=banner)? (y/n): n
[*] Rodando Nmap nas portas 22,80...
```

## 📜 Licença
Este projeto está licenciado sob a licença MIT. Veja o arquivo [LICENSE](https://github.com/GabrielMartorelli/redscan-toolkit/blob/main/LICENSE) para mais detalhes.

## 🙋‍♂️ Autor
- Gabriel Martorelli
- 🔗 linkedin.com/in/gabriel-martorelli
- 🐙 github.com/GabrielMartorelli

### Atualização do Script de Scanner

Esta nova versão do script traz diversas melhorias importantes para facilitar o uso em ambientes reais, especialmente quando se trabalha com múltiplos alvos.

### Novidades e melhorias:

- **Varredura em lote:** agora você pode fornecer um arquivo com múltiplos IPs para escanear de forma sequencial, aumentando a produtividade.
- **Validação aprimorada:** o script verifica se o arquivo de IPs está vazio, ignora linhas vazias ou IPs inválidos, evitando erros de execução.
- **Perguntas Nmap unificadas:** as opções do Nmap (-sS, -sT, -Pn, banner) são perguntadas apenas uma vez no início, para evitar repetição cansativa em múltiplos alvos.
- **Ping opcional:** o script tenta pingar o host para aviso, mas mesmo que o ping falhe, o scan prossegue, útil para redes que bloqueiam ICMP.
- **Arquivos organizados:** resultados do Rustscan e Nmap são salvos em arquivos separados por IP, facilitando a análise e gerenciamento.
- **Robustez:** o script não para se algum IP falhar, garantindo que a varredura continue para todos os hosts listados.
- **Controle de sudo:** mantém o sudo ativo durante toda a execução, evitando requisições repetidas de senha.
- **Timeout para Rustscan:** previne que hosts travem o script por muito tempo.
- **Logs coloridos e claros:** para facilitar o acompanhamento do processo.

### Uso recomendado:

- Crie um arquivo de IPs, um por linha, e forneça o caminho para o script.
- Configure as flags do Nmap apenas uma vez.
- Deixe o script rodar e confira os arquivos de saída para cada host.

---

Essas melhorias tornam o script mais flexível, robusto e prático para auditorias de rede e pentests em ambientes reais, onde múltiplos hosts precisam ser analisados rapidamente.




## 🔍 redscan-toolkit

[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Shell](https://img.shields.io/badge/Shell-Bash-blue.svg?logo=gnu-bash)](https://www.gnu.org/software/bash/)
[![RustScan](https://img.shields.io/badge/Scanner-RustScan-orange?logo=rust)](https://github.com/RustScan/RustScan)
[![Nmap](https://img.shields.io/badge/Scanner-Nmap-red?logo=nmap)](https://nmap.org/)
[![Status](https://img.shields.io/badge/Status-Stable-brightgreen.svg)](#)

Bash script for automating port scanning using Rustscan and Nmap.

> Ideal tool for security professionals and pentesters who need to quickly identify open ports and perform detailed scans.

---

## ⚙️ Requirements

- Bash (version 4.x or higher)
- [Rustscan](https://github.com/RustScan/RustScan)
- [Nmap](https://nmap.org/)
- Superuser permissions (`sudo`) to run Nmap

---

## 📦 Installation

```bash
git clone https://github.com/GabrielMartorelli/redscan.git
cd redscan
chmod +x portas.sh
```

## 🚀 Usage
Run the script with administrative privileges:
```bash
sudo ./ports.sh
```
## Features:
 - Prompts for the target IP address
 - Performs Rustscan port scan from ports 1 to 65535
 - Waits 20 seconds to avoid conflicts between tools
 - Allows selecting advanced Nmap options:
    - Scan SYN (-sS)
    - Skip host discovery (-Pn)
    - Banner grabbing script (--script=banner)
 - Runs Nmap on open ports detected by Rustscan
 - Saves output files:
    - Ports.txt: list of open ports found
    - allPorts.txt: full Nmap report

## 📁 Example Run
```text
[*] Current directory where the script is running: /home/user/redscan
Enter target IP: 192.168.1.100
[*] Running Rustscan on IP 192.168.1.100...
[*] Open ports found (saved in Ports.txt):
Open 192.168.1.100:22
Open 192.168.1.100:80
Use -sS flag (SYN scan) in Nmap? (y/n): y
Use -Pn flag in Nmap? (y/n): y
Use banner grabbing script (--script=banner)? (y/n): n
[*] Running Nmap on ports 22,80...
```

## 📜 License
This project is licensed under the MIT License. See the [LICENSE](https://github.com/GabrielMartorelli/redscan-toolkit/blob/main/LICENSE) file for details.

## 🙋‍♂️ Author
- Gabriel Martorelli
- 🔗 linkedin.com/in/gabriel-martorelli
- 🐙 github.com/GabrielMartorelli

# Scanner Script Update
This new version of the script brings several important improvements to make it easier to use in real environments, especially when working with multiple targets.

What's new and improved:

- **Batch scanning:** You can now provide a file with multiple IPs to scan sequentially, increasing productivity.
- **Enhanced validation:** The script checks if the IP file is empty, ignores empty lines or invalid IPs, preventing execution errors.
- **Unified Nmap prompts:** Nmap options (-sS, -sT, -Pn, banner) are asked only once at the start, avoiding repetitive prompts for multiple targets.
- **Optional ping check:** The script attempts to ping hosts as a warning, but will proceed with scanning even if ping fails — useful for networks blocking ICMP.
- **Organized output files:** Rustscan and Nmap results are saved in separate files per IP, making analysis and management easier.
- **Robustness:** The script doesn’t stop if an IP fails, ensuring scanning continues for all listed hosts.
- **Sudo management:** Keeps sudo active throughout the execution, avoiding repeated password prompts.
- **Timeout for Rustscan:** Prevents hosts from hanging the script for too long.
- **Clear and colorful logs:** Helps you easily follow the scanning process.

## Recommended usage:
- Create a file with one IP per line and provide its path to the script.
- Configure Nmap flags once.
- Let the script run and check the output files for each host.
