# MySQL Dump & Restore Docker Container

Este proyecto contiene scripts para crear dumps de MySQL y restaurarlos, empaquetados en un contenedor Docker.

## Archivos incluidos

- `dump.sh`: Script para crear dumps de base de datos MySQL remota vía túnel SSH
- `restore.sh`: Script para restaurar dumps en AWS RDS MySQL
- `Dockerfile`: Configuración del contenedor
- `docker-compose.yml`: Configuración de Docker Compose
- `.env.example`: Ejemplo de variables de entorno

## Uso

### Método simple (recomendado)

Usa el script helper incluido para simplificar las operaciones:

```bash
# 1. Configurar variables de entorno
cp .env.example .env
# Edita .env con tus credenciales reales

# 2. Construir y levantar
./docker-helper.sh build
./docker-helper.sh up

# 3. Crear un dump
./docker-helper.sh dump

# 4. Restaurar un dump
./docker-helper.sh restore dumps/api_hub_2025-09-29_1310.sql.gz

# 5. Acceso interactivo
./docker-helper.sh shell
```

### Método manual (Docker Compose)

#### 1. Configuración inicial

Copia el archivo de ejemplo de variables de entorno:
```bash
cp .env.example .env
```

Edita el archivo `.env` con tus credenciales reales.

#### 2. Construir la imagen

```bash
docker-compose build
```

#### 3. Ejecutar el contenedor

```bash
docker-compose up -d
```

#### 4. Ejecutar scripts

##### Para crear un dump:
```bash
docker-compose exec mysql-dump-restore ./dump-docker.sh
```

##### Para restaurar un dump:
```bash
docker-compose exec mysql-dump-restore ./restore-docker.sh /app/dumps/api_hub_2025-09-29_1310.sql.gz
```

#### 5. Acceso interactivo

Para entrar al contenedor de forma interactiva:
```bash
docker-compose exec mysql-dump-restore bash
```

## Variables de entorno

### Para dump.sh:
- `SSH_USER`: Usuario SSH
- `SSH_HOST`: Host SSH  
- `SSH_PORT`: Puerto SSH
- `DB_NAME`: Nombre de la base de datos
- `DB_USER`: Usuario de la base de datos
- `DB_PASS`: Contraseña de la base de datos

### Para restore.sh:
- `RDS_HOST`: Host de AWS RDS
- `RDS_PORT`: Puerto de RDS
- `RDS_DATABASE`: Nombre de la base de datos destino
- `RDS_USERNAME`: Usuario de RDS
- `RDS_PASSWORD`: Contraseña de RDS

## Volúmenes

- `./dumps:/app/dumps`: Directorio donde se guardan los dumps
- `~/.ssh:/root/.ssh:ro`: Claves SSH (solo lectura)

## Notas de seguridad

- Las credenciales se pasan como variables de entorno
- Los archivos temporales de credenciales se eliminan automáticamente
- Se usa `shred` para eliminar archivos con contraseñas de forma segura