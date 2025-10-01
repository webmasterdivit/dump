# Dockerfile para scripts de dump y restore de MySQL
FROM mysql:8.0-debian

# Instalar dependencias adicionales
RUN apt-get update && apt-get install -y \
    openssh-client \
    netcat-traditional \
    pv \
    gzip \
    && rm -rf /var/lib/apt/lists/*

# Crear directorio de trabajo
WORKDIR /app

# Copiar scripts y darles permisos de ejecución
COPY dump-docker.sh restore-docker.sh ./
RUN chmod +x dump-docker.sh restore-docker.sh

# Crear directorio para dumps
RUN mkdir -p /app/dumps

# Copiar dump existente si está presente
#COPY api_hub_2025-09-29_1310.sql.gz ./dumps/

# Variables de entorno por defecto (pueden sobrescribirse)
ENV SSH_USER=""
ENV SSH_HOST=""
ENV SSH_PORT="22"
ENV REMOTE_DB_HOST="127.0.0.1"
ENV REMOTE_DB_PORT="3306"
ENV LOCAL_HOST="127.0.0.1"
ENV LOCAL_PORT="11224"
ENV DB_NAME="api_hub"
ENV DB_USER=""
ENV DB_PASS=""

# Para restore
ENV RDS_HOST=""
ENV RDS_PORT="3306"
ENV RDS_DATABASE="hubapi"
ENV RDS_USERNAME=""
ENV RDS_PASSWORD=""
ENV SSL_MODE="REQUIRED"
ENV MAX_ALLOWED_PACKET="1G"

# Exponer puerto para túnel SSH (opcional)
EXPOSE 11224

# Punto de entrada por defecto
CMD ["bash"]