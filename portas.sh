#!/bin/bash
set -euo pipefail  # Configura o bash para sair em erros, usar variáveis não declaradas causa erro, e pipes falham se algum comando falhar

# Definição das cores para logs e ícones para melhorar visualização no terminal
GREEN="\033[0;32m"    # ✅ verde para informações
RED="\033[0;31m"      # ❌ vermelho para erros
BLUE="\033[0;34m"     # 🔷 azul para ações
YELLOW="\033[1;33m"   # ⚠️ amarelo para avisos
RESET="\033[0m"       # Reset da cor padrão

# Funções para exibir mensagens formatadas e coloridas no terminal
log_info() {
  echo -e "${GREEN}[*]${RESET} ${GREEN}$1${RESET}"
}

log_error() {
  echo -e "${RED}[*]${RESET} ${RED}$1${RESET}"
}

log_action() {
  echo -e "${BLUE}[*]${RESET} ${BLUE}$1${RESET}"
}

log_warn() {
  echo -e "${YELLOW}[*]${RESET} ${YELLOW}$1${RESET}"
}

# Função que pergunta as flags para o Nmap uma única vez no início da execução
ask_flags() {
  read -p "Deseja usar a flag -sS (SYN scan) no Nmap? (y/n): " usa_sS
  if [[ "$usa_sS" =~ ^[Yy]$ ]]; then
    scan_flag="-sS"
  else
    read -p "Deseja usar a flag -sT (TCP Connect scan) no Nmap? (y/n): " usa_sT
    if [[ "$usa_sT" =~ ^[Yy]$ ]]; then
      scan_flag="-sT"
    else
      scan_flag=""  # Nenhuma flag de scan específica selecionada
    fi
  fi

  # Pergunta sobre a flag -Pn (sem ping) para contornar firewalls bloqueando ICMP
  read -p "Deseja usar a flag -Pn no Nmap? (y/n): " usa_pn
  # Pergunta se deve usar o script banner grab para coleta de banners dos serviços
  read -p "Deseja usar o script de banner grab (--script=banner)? (y/n): " usa_banner
}

# Verifica se o script está rodando com permissões de root
if [[ "$EUID" -ne 0 ]]; then
  log_error "Este script precisa ser executado com privilégios elevados. Rode com sudo."
  exit 1
fi

# Solicita senha sudo antecipadamente para evitar múltiplos prompts durante execução
sudo -v

# Função para manter o sudo "ativo" durante todo o tempo do script, atualizando o timestamp a cada 60s
keep_sudo_alive() {
  while true; do sudo -n true; sleep 60; done
}
keep_sudo_alive &           # Roda em background
SUDO_PID=$!                # Salva PID do processo para matar no final
trap 'kill "$SUDO_PID"' EXIT  # Garante que o processo será morto ao sair do script

# Verifica se o Rustscan está instalado, ferramenta usada para varredura rápida de portas
if ! command -v rustscan &> /dev/null; then
  log_error "Rustscan não está instalado. Instale para continuar."
  exit 1
fi

# Verifica se o Nmap está instalado, ferramenta usada para scan detalhado nas portas encontradas
if ! command -v nmap &> /dev/null; then
  log_error "Nmap não está instalado. Instale para continuar."
  exit 1
fi

CUR_DIR="$(pwd)"  # Salva diretório atual
log_info "Diretório atual onde o script está rodando: $CUR_DIR"

# Testa permissão de escrita no diretório atual criando arquivo temporário
if ! touch test.tmp 2>/dev/null; then
  log_error "Sem permissão de escrita no diretório atual ($CUR_DIR)."
  exit 1
else
  rm -f test.tmp  # Remove arquivo temporário após teste
fi

# Solicita ao usuário o IP alvo ou caminho para arquivo contendo lista de IPs
read -p "Digite o IP alvo ou o caminho para o arquivo de IPs: " ALVO

# Se ALVO for arquivo, carrega a lista de IPs, caso contrário trata ALVO como único IP
if [[ -f "$ALVO" ]]; then
  # Verifica se o arquivo não está vazio
  if [[ ! -s "$ALVO" ]]; then
    log_error "Arquivo $ALVO está vazio. Abortando."
    exit 1
  fi
  mapfile -t IP_LIST < "$ALVO"  # Lê linhas do arquivo para array IP_LIST
else
  IP_LIST=("$ALVO")  # Coloca único IP no array
fi

# Confere se existe pelo menos 1 IP para escanear
if [[ ${#IP_LIST[@]} -eq 0 ]]; then
  log_error "Nenhum IP para escanear. Abortando."
  exit 1
fi

# Pergunta as flags Nmap apenas uma vez antes de começar o loop dos IPs
ask_flags

# Loop que percorre cada IP na lista para executar a varredura
for IP in "${IP_LIST[@]}"; do
  IP=$(echo "$IP" | xargs) # Remove espaços em branco no início/fim

  # Ignora IPs vazios
  if [[ -z "$IP" ]]; then
    log_warn "IP vazio encontrado na lista. Pulando."
    continue
  fi

  # Valida o formato do IP (IPv4 simples, sem validação de faixa)
  if ! [[ "$IP" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    log_warn "IP '$IP' inválido. Pulando."
    continue
  fi

  log_action "Iniciando varredura para o IP $IP..."

  # Testa ping - só avisa se não responder, mas prossegue com o scan (útil se ICMP bloqueado)
  if ! ping -c 1 -W 1 "$IP" &> /dev/null; then
    log_warn "IP $IP não responde a ping, mas seguirá para varredura."
  fi

  # Cria nomes seguros para arquivos baseados no IP, removendo caracteres suspeitos
  SAFE_IP=$(echo "$IP" | tr -cd '[:alnum:]._-')
  PORTS_FILE="Ports-${SAFE_IP}.txt"      # Arquivo para portas abertas encontradas pelo Rustscan
  NMAPP_FILE="allPorts-${SAFE_IP}.txt"   # Arquivo para resultados do Nmap

  rm -f "$PORTS_FILE" "$NMAPP_FILE"  # Remove arquivos antigos para evitar confusão

  log_action "Rodando Rustscan no IP $IP..."
  # Executa rustscan com timeout para evitar travamentos e salva só as linhas com "Open"
  if ! rustscan --no-banner -a "$IP" -r 1-65535 --ulimit 5000 --timeout 3000 | grep "^Open" > "$PORTS_FILE"; then
    log_warn "Rustscan falhou para $IP. Pulando este IP."
    continue
  fi
  chmod 664 "$PORTS_FILE"  # Dá permissão de leitura/escrita para dono e grupo
  log_info "Rustscan finalizado para $IP"

  # Verifica se encontrou alguma porta aberta
  if [[ ! -s "$PORTS_FILE" ]]; then
    log_warn "[*] Nenhuma porta aberta encontrada no IP $IP. Pulando para o próximo IP."
    continue
  fi

  # Exibe as portas abertas encontradas
  log_info "Portas abertas encontradas para $IP (salvas em $PORTS_FILE):"
  cat "$PORTS_FILE"

  # Extrai somente os números das portas para passar para o Nmap, separadas por vírgula
  portas=$(awk -F':' '/^Open/ {print $2}' "$PORTS_FILE" | tr '\n' ',' | sed 's/,$//')

  sleep 2  # Pequena pausa para evitar saturar o sistema/target

  # Monta array de argumentos para o Nmap conforme as flags selecionadas pelo usuário
  nmap_args=()
  if [[ -n "$scan_flag" ]]; then
    nmap_args+=("$scan_flag")
  fi
  nmap_args+=("-sCV")  # Scan padrão com scripts de detecção e versões
  if [[ "$usa_pn" =~ ^[Yy]$ ]]; then
    nmap_args+=("-Pn")  # Flag para não fazer ping prévio
  fi
  if [[ "$usa_banner" =~ ^[Yy]$ ]]; then
    nmap_args+=("--script=banner")  # Script para coleta de banners
  fi
  nmap_args+=("-p" "$portas" "$IP" "-oN" "$NMAPP_FILE")  # Define portas, IP e arquivo de saída

  log_action "Rodando Nmap nas portas $portas para $IP..."
  # Executa o Nmap com os argumentos montados
  if ! nmap "${nmap_args[@]}"; then
    log_warn "Nmap falhou para $IP."
  fi
  chmod 664 "$NMAPP_FILE" 2>/dev/null || true  # Ajusta permissões do arquivo, ignora erro

  log_info "Scan Nmap finalizado para $IP. Resultados salvos em $NMAPP_FILE"
  echo  # Linha em branco para separar visualmente os logs de cada IP
done
