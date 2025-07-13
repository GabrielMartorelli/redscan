#!/bin/bash
set -euo pipefail

# Cores para logs e ícones
GREEN="\033[0;32m"    # ✅
RED="\033[0;31m"      # ❌
BLUE="\033[0;34m"     # 🔷
YELLOW="\033[1;33m"   # ⚠️
RESET="\033[0m"

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

# Verifica se script está rodando como root
if [[ "$EUID" -ne 0 ]]; then
  log_error "Este script precisa ser executado com privilégios elevados. Rode com sudo."
  exit 1
fi

# Pede a senha sudo (para garantir que o cache sudo está ativo)
sudo -v

# Mantém o sudo ativo durante toda a execução
( while true; do sudo -n true; sleep 60; done ) 2>/dev/null &

# Verifica se rustscan está instalado
if ! command -v rustscan &> /dev/null; then
  log_error "Rustscan não está instalado. Instale para continuar."
  exit 1
fi

# Verifica se nmap está instalado
if ! command -v nmap &> /dev/null; then
  log_error "Nmap não está instalado. Instale para continuar."
  exit 1
fi

CUR_DIR="$(pwd)"
log_info "Diretório atual onde o script está rodando: $CUR_DIR"

read -p "Digite o IP alvo: " IP

if [[ -z "$IP" ]]; then
  log_error "IP não pode ficar vazio. Abortando."
  exit 1
fi

# Remove arquivos antigos para evitar prompts de confirmação e problemas de permissão
rm -f Ports.txt allPorts.txt

log_action "Rodando Rustscan no IP $IP..."

rustscan --no-banner -a "$IP" -r 1-65535 --ulimit 5000 | grep "^Open" > Ports.txt
chmod 644 Ports.txt

if [[ ! -s Ports.txt ]]; then
  log_warn "Nenhuma porta aberta encontrada no IP $IP."
  exit 1
fi

log_info "Portas abertas encontradas (salvas em Ports.txt):"
cat Ports.txt

# Extrai apenas o número da porta (parte após o ':') para o Nmap
portas=$(awk -F':' '/^Open/ {print $2}' Ports.txt | tr '\n' ',' | sed 's/,$//')

sleep 20

read -p "Deseja usar a flag -sS (SYN scan) no Nmap? (y/n): " usa_sS
if [[ "$usa_sS" =~ ^[Yy]$ ]]; then
  scan_flag="-sS"
else
  read -p "Deseja usar a flag -sT (TCP Connect scan) no Nmap? (y/n): " usa_sT
  if [[ "$usa_sT" =~ ^[Yy]$ ]]; then
    scan_flag="-sT"
  else
    scan_flag=""
  fi
fi

read -p "Deseja usar a flag -Pn no Nmap? (y/n): " usa_pn

read -p "Deseja usar o script de banner grab (--script=banner)? (y/n): " usa_banner

nmap_args=()

if [[ -n "$scan_flag" ]]; then
  nmap_args+=("$scan_flag")
fi

nmap_args+=("-sCV")

if [[ "$usa_pn" =~ ^[Yy]$ ]]; then
  nmap_args+=("-Pn")
fi

if [[ "$usa_banner" =~ ^[Yy]$ ]]; then
  nmap_args+=("--script=banner")
fi

nmap_args+=("-p" "$portas" "$IP" "-oN" "allPorts.txt")

log_action "Rodando Nmap nas portas $portas..."

nmap "${nmap_args[@]}"
chmod 644 allPorts.txt 2>/dev/null || true

log_info "Scan Nmap finalizado. Resultados salvos em allPorts.txt"
