# ad-spray.sh
Script BASH para realizar spraying de contraseñas en entornos de AD utilizando SMBClient.
### Uso
./ad-spray_v1.sh -U [archivo_usuarios] -u [usuario] -P [archivo_contraseñas] -p [contraseña] -s [servidor] -d [dominio] -t [nivel_de_tiempo]

##### Opciones:
- 	-U    Archivo con la lista de usuarios (uno por línea)
- 	-u    Un único usuario
- 	-P    Archivo con la lista de contraseñas (una por línea)
- 	-p    Una única contraseña
- 	-s    Servidor SMB (por ejemplo, 192.168.1.10)
- 	-d    Dominio (opcional)
- 	-t    Nivel de tiempo (1: Paranoid, 2: Stealth (por defecto), 3: Fast, 4: More fast)
