# ad-spray.sh
Script bash que realiza ataques de password Sprying y fuerza bruta sobre servidores SMB en entornos de AD, utilizando la herramienta smbclient. 

### Uso
./ad-spray.sh -U [archivo_usuarios] -p [contraseña] -s [servidor] -d [dominio]

##### Opciones:
- 	-U    Archivo con la lista de usuarios (uno por línea)
- 	-u    Un único usuario
- 	-P    Archivo con la lista de contraseñas (una por línea)
- 	-p    Una única contraseña
- 	-s    Servidor SMB (por ejemplo, 192.168.1.10)
- 	-d    Dominio (opcional)
- 	-t    Velocidad (1: Paranoid, 2: Stealth (por defecto), 3: Fast, 4: More fast)
