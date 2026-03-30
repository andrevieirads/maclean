#!/usr/bin/env bash
# =============================================================================
#  MacLean — Limpeza Inteligente para macOS
#  Versão: 1.0.0 | Compatível com macOS Catalina (10.15) ou superior
#  Inspirado no Script Baboo v3.2 (baboo.com.br)
# =============================================================================
#
#  USO:
#    chmod +x maclean.sh
#    ./maclean.sh [opções]
#
#  OPÇÕES:
#    --dry-run         Simula a limpeza sem apagar nada (recomendado na 1ª vez)
#    --safe            Modo conservador: apenas caches do usuário e logs
#    --aggressive      Limpeza mais profunda (inclui Docker, caches de sistema)
#    --auto            Sem perguntas interativas (útil em agendamentos)
#    --only-cache      Limpa apenas caches
#    --only-logs       Limpa apenas logs
#    --only-browsers   Limpa apenas caches de navegadores
#    --only-trash      Esvazia apenas a lixeira
#    -h | --help       Exibe esta ajuda
#
#  EXEMPLOS:
#    ./maclean.sh --dry-run                  # Simulação segura
#    ./maclean.sh --safe                     # Limpeza leve
#    sudo ./maclean.sh --aggressive          # Limpeza completa (requer sudo)
#    ./maclean.sh --only-browsers --auto     # Limpa navegadores sem perguntar
#
#  ⚠️  ATENÇÃO:
#    Algumas operações requerem privilégios de administrador (sudo).
#    O script nunca apaga: ~/Documents, ~/Desktop, ~/Downloads,
#    arquivos pessoais, nem arquivos críticos do sistema.
#
# =============================================================================

set -euo pipefail

# =============================================================================
#  CONFIGURAÇÕES GLOBAIS
# =============================================================================

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="MacLean"
readonly LOG_FILE="${TMPDIR:-/tmp}/maclean_$(date +%Y%m%d_%H%M%S).log"

# Flags de controle (valores padrão)
DRY_RUN=false
SAFE_MODE=false
AGGRESSIVE=false
AUTO_MODE=false
ONLY_CACHE=false
ONLY_LOGS=false
ONLY_BROWSERS=false
ONLY_TRASH=false
IS_ROOT=false
SPACE_BEFORE=0
SPACE_AFTER=0
TOTAL_CLEANED=0

# =============================================================================
#  CORES E FORMATAÇÃO
# =============================================================================

# Detecta suporte a cores
if [[ -t 1 ]] && command -v tput &>/dev/null && tput colors &>/dev/null; then
    RED=$(tput setaf 1)
    GREEN=$(tput setaf 2)
    YELLOW=$(tput setaf 3)
    BLUE=$(tput setaf 4)
    MAGENTA=$(tput setaf 5)
    CYAN=$(tput setaf 6)
    WHITE=$(tput setaf 7)
    BOLD=$(tput bold)
    DIM=$(tput dim)
    RESET=$(tput sgr0)
else
    RED="" GREEN="" YELLOW="" BLUE="" MAGENTA="" CYAN="" WHITE=""
    BOLD="" DIM="" RESET=""
fi

# =============================================================================
#  FUNÇÕES DE LOG
# =============================================================================

log_info()    { echo "${CYAN}  ℹ ${RESET} $*" | tee -a "$LOG_FILE"; }
log_success() { echo "${GREEN}  ✓ ${RESET} $*" | tee -a "$LOG_FILE"; }
log_warn()    { echo "${YELLOW}  ⚠ ${RESET} $*" | tee -a "$LOG_FILE"; }
log_error()   { echo "${RED}  ✗ ${RESET} $*" | tee -a "$LOG_FILE" >&2; }
log_section() {
    echo "" | tee -a "$LOG_FILE"
    echo "${BOLD}${BLUE}══════════════════════════════════════════════════${RESET}" | tee -a "$LOG_FILE"
    echo "${BOLD}${BLUE}  $*${RESET}" | tee -a "$LOG_FILE"
    echo "${BOLD}${BLUE}══════════════════════════════════════════════════${RESET}" | tee -a "$LOG_FILE"
}
log_dry()     { echo "${MAGENTA}  ⟳ ${RESET}${DIM}[DRY-RUN] Removeria: $*${RESET}" | tee -a "$LOG_FILE"; }

# =============================================================================
#  BANNER
# =============================================================================

show_banner() {
    echo ""
    echo "${BOLD}${CYAN}"
    echo "  ███╗   ███╗ █████╗  ██████╗██╗     ███████╗ █████╗ ███╗  ██╗"
    echo "  ████╗ ████║██╔══██╗██╔════╝██║     ██╔════╝██╔══██╗████╗ ██║"
    echo "  ██╔████╔██║███████║██║     ██║     █████╗  ███████║██╔██╗██║"
    echo "  ██║╚██╔╝██║██╔══██║██║     ██║     ██╔══╝  ██╔══██║██║╚████║"
    echo "  ██║ ╚═╝ ██║██║  ██║╚██████╗███████╗███████╗██║  ██║██║ ╚███║"
    echo "  ╚═╝     ╚═╝╚═╝  ╚═╝ ╚═════╝╚══════╝╚══════╝╚═╝  ╚═╝╚═╝  ╚══╝"
    echo "${RESET}"
    echo "  ${BOLD}${WHITE}Limpeza Inteligente para macOS — v${SCRIPT_VERSION}${RESET}"
    echo "  ${DIM}Inspirado no Script Baboo | github.com/seu-usuario/maclean${RESET}"
    echo ""

    # Exibe flags ativas
    local flags_ativas=""
    $DRY_RUN     && flags_ativas+="${YELLOW}[DRY-RUN] ${RESET}"
    $SAFE_MODE   && flags_ativas+="${GREEN}[SAFE] ${RESET}"
    $AGGRESSIVE  && flags_ativas+="${RED}[AGGRESSIVE] ${RESET}"
    $AUTO_MODE   && flags_ativas+="${CYAN}[AUTO] ${RESET}"
    [[ -n "$flags_ativas" ]] && echo "  Modo: ${flags_ativas}" && echo ""
}

# =============================================================================
#  AJUDA
# =============================================================================

show_help() {
    show_banner
    sed -n '/^#  USO:/,/^# ====/p' "$0" | head -n -1 | sed 's/^#  \?/  /'
    exit 0
}

# =============================================================================
#  PARSE DE ARGUMENTOS
# =============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)       DRY_RUN=true ;;
            --safe)          SAFE_MODE=true ;;
            --aggressive)    AGGRESSIVE=true ;;
            --auto)          AUTO_MODE=true ;;
            --only-cache)    ONLY_CACHE=true ;;
            --only-logs)     ONLY_LOGS=true ;;
            --only-browsers) ONLY_BROWSERS=true ;;
            --only-trash)    ONLY_TRASH=true ;;
            -h|--help)       show_help ;;
            *)
                log_error "Opção desconhecida: $1"
                echo "  Use --help para ver as opções disponíveis."
                exit 1
                ;;
        esac
        shift
    done

    # Valida combinações inválidas
    if $SAFE_MODE && $AGGRESSIVE; then
        log_error "--safe e --aggressive não podem ser usados juntos."
        exit 1
    fi
}

# =============================================================================
#  VERIFICAÇÕES DO AMBIENTE
# =============================================================================

check_environment() {
    # Detecta macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "Este script é exclusivo para macOS."
        exit 1
    fi

    # Versão mínima: Catalina (10.15 = ProductVersion 10.15.x)
    local os_version
    os_version=$(sw_vers -productVersion)
    local major minor
    major=$(echo "$os_version" | cut -d. -f1)
    minor=$(echo "$os_version" | cut -d. -f2)

    if [[ "$major" -eq 10 && "$minor" -lt 15 ]]; then
        log_error "macOS $os_version não é suportado. Requer Catalina (10.15) ou superior."
        exit 1
    fi

    # Detecta root
    if [[ "$EUID" -eq 0 ]]; then
        IS_ROOT=true
        log_warn "Executando como root. Limpeza de sistema habilitada."
    fi

    # Cria arquivo de log
    touch "$LOG_FILE" 2>/dev/null || true
    log_info "Log salvo em: ${DIM}${LOG_FILE}${RESET}"
}

# =============================================================================
#  UTILITÁRIOS
# =============================================================================

# Espaço em disco disponível em MB
get_free_space_mb() {
    df -m / | awk 'NR==2 {print $4}'
}

# Tamanho de um caminho em formato legível
get_size() {
    local path="$1"
    if [[ -e "$path" ]]; then
        du -sh "$path" 2>/dev/null | awk '{print $1}' || echo "0B"
    else
        echo "0B"
    fi
}

# Remove com segurança: valida o caminho, loga e executa
safe_remove() {
    local target="$1"
    local description="${2:-$1}"

    # Proteções absolutas — nunca apaga estes caminhos
    local protected=(
        "$HOME"
        "$HOME/Documents"
        "$HOME/Desktop"
        "$HOME/Downloads"
        "$HOME/Pictures"
        "$HOME/Movies"
        "$HOME/Music"
        "/System"
        "/usr"
        "/bin"
        "/sbin"
        "/etc"
        "/Applications"
        "/"
    )

    # Verifica se o alvo é ou está dentro de um caminho protegido
    for prot in "${protected[@]}"; do
        if [[ "$target" == "$prot" || "$target" == "$prot/"* ]]; then
            log_warn "Caminho protegido ignorado: ${DIM}${target}${RESET}"
            return 0
        fi
    done

    # Verifica existência
    if [[ ! -e "$target" && ! -L "$target" ]]; then
        return 0  # Não existe, silencioso
    fi

    local size
    size=$(get_size "$target")

    if $DRY_RUN; then
        log_dry "$description (${size})"
        return 0
    fi

    # Remove com tratamento de erro
    if rm -rf "$target" 2>/dev/null; then
        log_success "Removido: ${DIM}${description}${RESET} ${GREEN}(${size})${RESET}"
    else
        log_warn "Não foi possível remover: ${DIM}${description}${RESET} (permissão negada ou em uso)"
    fi
}

# Remove apenas o conteúdo de um diretório, preservando o diretório pai
safe_remove_contents() {
    local dir="$1"
    local description="${2:-conteúdo de $1}"

    [[ ! -d "$dir" ]] && return 0

    local size
    size=$(get_size "$dir")

    if $DRY_RUN; then
        log_dry "$description (${size})"
        return 0
    fi

    # Itera e remove cada item filho
    local count=0
    while IFS= read -r -d '' item; do
        if rm -rf "$item" 2>/dev/null; then
            (( count++ )) || true
        fi
    done < <(find "$dir" -maxdepth 1 -mindepth 1 -print0 2>/dev/null)

    if [[ $count -gt 0 ]]; then
        log_success "Limpo: ${DIM}${description}${RESET} ${GREEN}(${size} liberado)${RESET}"
    fi
}

# Confirmação interativa
confirm() {
    local message="$1"
    $AUTO_MODE && return 0
    $DRY_RUN   && return 0

    echo ""
    echo -n "  ${YELLOW}${BOLD}?${RESET} ${message} ${DIM}[s/N]${RESET} "
    read -r resposta
    case "$resposta" in
        [sS]|[yY]|[sS][iI][mM]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# Detecta se um aplicativo está instalado
app_exists() {
    local app_name="$1"
    [[ -d "/Applications/${app_name}.app" ]] || \
    [[ -d "$HOME/Applications/${app_name}.app" ]] || \
    command -v "$app_name" &>/dev/null
}

# Mata processo se estiver rodando
kill_if_running() {
    local process="$1"
    if pgrep -xq "$process" 2>/dev/null; then
        log_warn "Encerrando processo: ${process}..."
        if ! $DRY_RUN; then
            killall "$process" 2>/dev/null || true
            sleep 1
        fi
    fi
}

# =============================================================================
#  MÓDULO 1 — CACHES DO USUÁRIO
# =============================================================================

clean_user_caches() {
    log_section "🗂  Caches do Usuário"

    # Cache geral
    safe_remove_contents "$HOME/Library/Caches" "~/Library/Caches"

    # Caches de containers (aplicativos sandboxed)
    if [[ -d "$HOME/Library/Containers" ]]; then
        while IFS= read -r -d '' container_cache; do
            safe_remove_contents "$container_cache" "Container cache: ${container_cache##*/Library/Containers/}"
        done < <(find "$HOME/Library/Containers" \
            -maxdepth 4 \
            -type d \
            -name "Caches" \
            -print0 2>/dev/null)
    fi

    # Application Support caches
    safe_remove_contents "$HOME/Library/Application Support/CrashReporter" \
        "~/Library/Application Support/CrashReporter"
}

# =============================================================================
#  MÓDULO 2 — LOGS DO USUÁRIO
# =============================================================================

clean_user_logs() {
    log_section "📋 Logs do Usuário"

    safe_remove_contents "$HOME/Library/Logs" "~/Library/Logs"
    safe_remove_contents "$HOME/Library/Logs/DiagnosticReports" \
        "Crash reports do usuário"
}

# =============================================================================
#  MÓDULO 3 — ARQUIVOS TEMPORÁRIOS
# =============================================================================

clean_temp_files() {
    log_section "🗃  Arquivos Temporários"

    safe_remove_contents "/tmp" "/tmp"
    safe_remove_contents "/private/var/tmp" "/private/var/tmp"

    # Arquivos .DS_Store no home (não recursivo para evitar danos)
    if $DRY_RUN; then
        local count
        count=$(find "$HOME" -maxdepth 3 -name ".DS_Store" 2>/dev/null | wc -l | tr -d ' ')
        log_dry "${count} arquivos .DS_Store em ~/... (máx 3 níveis)"
    else
        local removed=0
        while IFS= read -r -d '' ds; do
            rm -f "$ds" 2>/dev/null && (( removed++ )) || true
        done < <(find "$HOME" -maxdepth 3 -name ".DS_Store" -print0 2>/dev/null)
        [[ $removed -gt 0 ]] && log_success "Removidos ${removed} arquivos .DS_Store"
    fi
}

# =============================================================================
#  MÓDULO 4 — LOGS DO SISTEMA (requer sudo)
# =============================================================================

clean_system_logs() {
    log_section "🖥  Logs do Sistema"

    if ! $IS_ROOT && ! $DRY_RUN; then
        log_warn "Logs do sistema requerem sudo. Pulando (execute com sudo para incluir)."
        return 0
    fi

    safe_remove_contents "/private/var/log" "/private/var/log"
    safe_remove_contents "/Library/Logs" "/Library/Logs"
    safe_remove_contents "/Library/Logs/DiagnosticReports" \
        "Crash reports do sistema"

    # Limpa logs via log rotate nativo do macOS
    if ! $DRY_RUN; then
        log_info "Executando rotação de logs do sistema..."
        newsyslog -rnf /etc/newsyslog.conf 2>/dev/null || true
    fi
}

# =============================================================================
#  MÓDULO 5 — CACHES DO SISTEMA (requer sudo)
# =============================================================================

clean_system_caches() {
    log_section "💾 Caches do Sistema"

    if ! $IS_ROOT && ! $DRY_RUN; then
        log_warn "Caches do sistema requerem sudo. Pulando."
        return 0
    fi

    safe_remove_contents "/Library/Caches" "/Library/Caches"

    # Cache do kernel/kext — apenas modo agressivo
    if $AGGRESSIVE; then
        log_warn "Modo agressivo: limpando cache de kexts..."
        safe_remove "/System/Library/Caches/com.apple.kext.caches" \
            "Cache de kernel extensions"
    fi
}

# =============================================================================
#  MÓDULO 6 — LIXEIRA
# =============================================================================

clean_trash() {
    log_section "🗑  Lixeira"

    safe_remove_contents "$HOME/.Trash" "Lixeira do usuário"

    # Lixeiras de volumes externos
    if [[ -d "/Volumes" ]]; then
        while IFS= read -r -d '' trashes; do
            safe_remove_contents "$trashes" "Lixeira: ${trashes%%/.Trashes}"
        done < <(find /Volumes -maxdepth 2 -name ".Trashes" -type d -print0 2>/dev/null)
    fi
}

# =============================================================================
#  MÓDULO 7 — SAFARI
# =============================================================================

clean_safari() {
    [[ -d "$HOME/Library/Safari" ]] || return 0
    log_section "🧭 Safari"

    kill_if_running "Safari"

    safe_remove_contents "$HOME/Library/Caches/com.apple.Safari" \
        "Safari — Cache"
    safe_remove "$HOME/Library/Safari/WebpageIcons.db" \
        "Safari — WebpageIcons.db"
    safe_remove_contents "$HOME/Library/WebKit/com.apple.Safari" \
        "Safari — WebKit cache"

    # Cache de media
    safe_remove_contents \
        "$HOME/Library/Containers/com.apple.Safari/Data/Library/Caches" \
        "Safari — Container cache"
}

# =============================================================================
#  MÓDULO 8 — GOOGLE CHROME
# =============================================================================

clean_chrome() {
    local chrome_base="$HOME/Library/Application Support/Google/Chrome"
    [[ -d "$chrome_base" ]] || return 0
    log_section "🌐 Google Chrome"

    kill_if_running "Google Chrome"

    local profiles=("Default" "Guest Profile")
    for i in $(seq 1 12); do
        profiles+=("Profile $i")
    done

    for profile in "${profiles[@]}"; do
        local profile_path="${chrome_base}/${profile}"
        [[ -d "$profile_path" ]] || continue

        safe_remove_contents "${profile_path}/Cache/Cache_Data" \
            "Chrome [${profile}] — Cache"
        safe_remove_contents "${profile_path}/GPUCache" \
            "Chrome [${profile}] — GPU Cache"
        safe_remove_contents "${profile_path}/Code Cache/js" \
            "Chrome [${profile}] — JS Code Cache"
        safe_remove_contents "${profile_path}/Code Cache/wasm" \
            "Chrome [${profile}] — WASM Cache"
        safe_remove_contents "${profile_path}/Service Worker/CacheStorage" \
            "Chrome [${profile}] — Service Worker Cache"
        safe_remove_contents "${profile_path}/Service Worker/ScriptCache" \
            "Chrome [${profile}] — Service Worker Scripts"

        # Logs e journals (seguros de apagar)
        find "${profile_path}" -maxdepth 2 \
            \( -name "*.log" -o -name "History-journal" \) \
            -delete 2>/dev/null || true
    done

    # Métricas e crash reports
    safe_remove "${chrome_base}/BrowserMetrics" "Chrome — BrowserMetrics"
    find "${chrome_base}" -maxdepth 1 -name "*.pma" -delete 2>/dev/null || true
}

# =============================================================================
#  MÓDULO 9 — SPOTIFY
# =============================================================================

clean_spotify() {
    local spotify_cache="$HOME/Library/Caches/com.spotify.client"
    [[ -d "$spotify_cache" ]] || return 0
    log_section "🎵 Spotify"

    kill_if_running "Spotify"

    safe_remove_contents "$spotify_cache" "Spotify — Cache"
    safe_remove_contents \
        "$HOME/Library/Application Support/Spotify/PersistentCache" \
        "Spotify — Cache Persistente"
}

# =============================================================================
#  MÓDULO 10 — SLACK
# =============================================================================

clean_slack() {
    local slack_base="$HOME/Library/Application Support/Slack"
    [[ -d "$slack_base" ]] || return 0
    log_section "💬 Slack"

    kill_if_running "Slack"

    safe_remove_contents "$HOME/Library/Caches/com.tinyspeck.slackmacgap" \
        "Slack — Cache"
    safe_remove_contents "${slack_base}/Cache" \
        "Slack — Cache de app"
    safe_remove_contents "${slack_base}/GPUCache" \
        "Slack — GPU Cache"
    safe_remove_contents "${slack_base}/Service Worker/CacheStorage" \
        "Slack — Service Worker"

    # Logs
    find "${slack_base}" -maxdepth 3 -name "*.log" -delete 2>/dev/null || true
}

# =============================================================================
#  MÓDULO 11 — DISCORD
# =============================================================================

clean_discord() {
    local discord_base="$HOME/Library/Application Support/discord"
    [[ -d "$discord_base" ]] || return 0
    log_section "🎮 Discord"

    kill_if_running "Discord"

    safe_remove_contents "$HOME/Library/Caches/com.hnc.Discord" \
        "Discord — Cache"
    safe_remove_contents "${discord_base}/Cache" \
        "Discord — Cache de app"
    safe_remove_contents "${discord_base}/GPUCache" \
        "Discord — GPU Cache"
    safe_remove_contents "${discord_base}/Code Cache" \
        "Discord — Code Cache"

    # Logs e dumps
    find "${discord_base}" -maxdepth 3 \
        \( -name "*.log" -o -name "*.dmp" \) \
        -delete 2>/dev/null || true
}

# =============================================================================
#  MÓDULO 12 — DOCKER (modo agressivo)
# =============================================================================

clean_docker() {
    command -v docker &>/dev/null || return 0
    log_section "🐳 Docker"

    if ! $AGGRESSIVE; then
        log_warn "Docker: limpeza completa requer --aggressive. Pulando."
        return 0
    fi

    if pgrep -xq "Docker" 2>/dev/null; then
        log_info "Limpando recursos Docker não utilizados..."
        if ! $DRY_RUN; then
            docker system prune -f 2>/dev/null \
                && log_success "Docker — system prune concluído" \
                || log_warn "Docker — falha no prune (Docker está ativo?)"
        else
            log_dry "docker system prune -f"
        fi
    else
        log_warn "Docker não está em execução. Pulando limpeza."
    fi
}

# =============================================================================
#  MÓDULO 13 — CACHES AGRESSIVOS ADICIONAIS
# =============================================================================

clean_aggressive_extras() {
    $AGGRESSIVE || return 0
    log_section "⚡ Limpeza Agressiva Adicional"

    # Cache de atualização do sistema
    safe_remove_contents "/Library/Updates" "Cache de atualizações do sistema"

    # Cache do Homebrew (se instalado)
    if command -v brew &>/dev/null; then
        log_info "Limpando cache do Homebrew..."
        if ! $DRY_RUN; then
            brew cleanup --prune=all 2>/dev/null \
                && log_success "Homebrew — cache limpo" \
                || log_warn "Homebrew — falha na limpeza"
        else
            log_dry "brew cleanup --prune=all"
        fi
    fi

    # Limpa caches do pip (Python)
    if command -v pip3 &>/dev/null; then
        if ! $DRY_RUN; then
            pip3 cache purge 2>/dev/null \
                && log_success "pip — cache limpo" \
                || true
        else
            log_dry "pip3 cache purge"
        fi
    fi

    # Cache do npm
    if command -v npm &>/dev/null; then
        if ! $DRY_RUN; then
            npm cache clean --force 2>/dev/null \
                && log_success "npm — cache limpo" \
                || true
        else
            log_dry "npm cache clean --force"
        fi
    fi

    # Cache do Xcode (se instalado)
    local xcode_cache="$HOME/Library/Developer/Xcode/DerivedData"
    if [[ -d "$xcode_cache" ]]; then
        safe_remove_contents "$xcode_cache" "Xcode — DerivedData"
    fi

    local xcode_archives="$HOME/Library/Developer/Xcode/Archives"
    if [[ -d "$xcode_archives" ]] && confirm "Remover Xcode Archives? (builds anteriores)"; then
        safe_remove_contents "$xcode_archives" "Xcode — Archives"
    fi
}

# =============================================================================
#  LIMPEZA DE MEMÓRIA (purge)
# =============================================================================

purge_memory() {
    $AGGRESSIVE || return 0
    log_section "🧠 Memória"

    if $IS_ROOT; then
        log_info "Liberando memória inativa..."
        if ! $DRY_RUN; then
            purge 2>/dev/null \
                && log_success "Memória inativa liberada." \
                || log_warn "Falha ao executar 'purge'."
        else
            log_dry "purge (liberar memória inativa)"
        fi
    else
        log_warn "Liberação de memória requer sudo. Pulando."
    fi
}

# =============================================================================
#  RELATÓRIO FINAL
# =============================================================================

show_report() {
    SPACE_AFTER=$(get_free_space_mb)
    local gained=$(( SPACE_AFTER - SPACE_BEFORE ))

    echo ""
    echo "${BOLD}${GREEN}══════════════════════════════════════════════════${RESET}"
    echo "${BOLD}${GREEN}  ✓  Limpeza Concluída${RESET}"
    echo "${BOLD}${GREEN}══════════════════════════════════════════════════${RESET}"
    echo ""

    if $DRY_RUN; then
        echo "  ${YELLOW}Modo DRY-RUN: nenhum arquivo foi apagado.${RESET}"
        echo "  Execute sem --dry-run para aplicar as mudanças."
    else
        if [[ $gained -gt 0 ]]; then
            echo "  ${GREEN}${BOLD}Espaço liberado: ~${gained} MB${RESET}"
        else
            echo "  ${DIM}Espaço liberado: menos de 1 MB${RESET}"
            echo "  ${DIM}(Muitos arquivos já podiam estar limpos ou em uso)${RESET}"
        fi

        echo ""
        echo "  ${DIM}Espaço disponível antes: ${SPACE_BEFORE} MB${RESET}"
        echo "  ${DIM}Espaço disponível depois: ${SPACE_AFTER} MB${RESET}"
    fi

    echo ""
    echo "  ${DIM}Log completo salvo em: ${LOG_FILE}${RESET}"
    echo ""
}

# =============================================================================
#  CONFIRMAÇÃO INICIAL
# =============================================================================

show_warning() {
    $AUTO_MODE && return 0
    $DRY_RUN   && return 0

    echo ""
    echo "  ${YELLOW}${BOLD}⚠  ATENÇÃO${RESET}"
    echo "  Este script irá remover arquivos temporários e caches."
    echo "  Certifique-se de que seus aplicativos estão fechados."
    echo ""
    echo "  O script ${BOLD}NUNCA${RESET} apaga:"
    echo "  ${DIM}• ~/Documents, ~/Desktop, ~/Downloads, ~/Pictures${RESET}"
    echo "  ${DIM}• Arquivos pessoais ou dados de sessão${RESET}"
    echo "  ${DIM}• Arquivos críticos do sistema${RESET}"
    echo ""
    echo -n "  ${BOLD}Deseja continuar? [s/N]${RESET} "
    read -r resposta
    case "$resposta" in
        [sS]|[yY]|[sS][iI][mM]|[yY][eE][sS]) : ;;
        *) echo "  Operação cancelada."; exit 0 ;;
    esac
}

# =============================================================================
#  ORQUESTRADOR PRINCIPAL
# =============================================================================

run_all() {
    # Determina quais módulos rodar
    local run_cache=true
    local run_logs=true
    local run_temp=true
    local run_browsers=true
    local run_trash=true
    local run_system=true

    # Flags --only-* sobrescrevem tudo
    if $ONLY_CACHE || $ONLY_LOGS || $ONLY_BROWSERS || $ONLY_TRASH; then
        run_cache=false; run_logs=false; run_temp=false
        run_browsers=false; run_trash=false; run_system=false

        $ONLY_CACHE    && run_cache=true
        $ONLY_LOGS     && run_logs=true
        $ONLY_BROWSERS && run_browsers=true
        $ONLY_TRASH    && run_trash=true
    fi

    # Modo seguro desativa limpeza de sistema
    $SAFE_MODE && run_system=false

    # Executa módulos
    $run_temp     && clean_temp_files
    $run_cache    && clean_user_caches
    $run_logs     && clean_user_logs
    $run_system   && clean_system_logs
    $run_system   && clean_system_caches
    $run_trash    && clean_trash

    # Navegadores e apps
    if $run_browsers; then
        clean_safari
        clean_chrome
        clean_spotify
        clean_slack
        clean_discord
    fi

    # Extras agressivos
    clean_docker
    clean_aggressive_extras
    purge_memory
}

# =============================================================================
#  ENTRY POINT
# =============================================================================

main() {
    parse_args "$@"
    check_environment
    show_banner
    show_warning

    SPACE_BEFORE=$(get_free_space_mb)

    log_info "Iniciando limpeza em: $(date '+%d/%m/%Y %H:%M:%S')"
    log_info "macOS: $(sw_vers -productVersion) | Usuário: $(whoami)"
    echo ""

    run_all
    show_report
}

main "$@"