# ad-spray.sh
Script bash que realiza ataques de password Sprying y fuerza bruta sobre servidores SMB en entornos de AD, utilizando la herramienta smbclient. 

## Uso
``` bash
./ad-spray.sh -U [archivo_usuarios] -p [contraseña] -s [servidor] -d [dominio]
```

##### Opciones:
```
 	-U    Archivo con la lista de usuarios (uno por línea)
 	-u    Un único usuario
 	-P    Archivo con la lista de contraseñas (una por línea)
 	-p    Una única contraseña
 	-s    Servidor SMB (por ejemplo, 192.168.1.10)
 	-d    Dominio (opcional)
 	-t    Velocidad (1: Paranoid, 2: Stealth (por defecto), 3: Fast, 4: More fast)
```

## Instalación

Es necesario tener instalada la herramienta smbclient para utilizar este script.

```bash
  sudo apt install smbclient
  git pull https://github.com/fedeScripts/ad-spray.sh.git
  cd ad-spray.sh && chmod +x ad-spray.sh
  ./ad-spray.sh
```

## Autor
- Federico Galarza  - [@fedeScripts](https://github.com/fedeScripts) 

[![linkedin](https://img.shields.io/badge/linkedin-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white)](https://www.linkedin.com/in/federico-galarza)
