#!/bin/bash

# Script helper para usar los contenedores Docker de dump/restore MySQL

show_help() {
    echo "Uso: $0 [comando] [argumentos]"
    echo ""
    echo "Comandos disponibles:"
    echo "  build       - Construir la imagen Docker"
    echo "  up          - Levantar el contenedor en segundo plano"
    echo "  down        - Parar y eliminar el contenedor"
    echo "  dump        - Ejecutar dump de la base de datos remota"
    echo "  restore     - Restaurar un dump en RDS (requiere archivo como argumento)"
    echo "  shell       - Abrir shell interactivo en el contenedor"
    echo "  logs        - Ver logs del contenedor"
    echo ""
    echo "Ejemplos:"
    echo "  $0 build                                    # Construir imagen"
    echo "  $0 up                                       # Levantar contenedor"
    echo "  $0 dump                                     # Crear dump"
    echo "  $0 restore dumps/api_hub_2025-09-29_1310.sql.gz  # Restaurar dump"
    echo "  $0 shell                                    # Acceso interactivo"
}

case "${1:-}" in
    "build")
        echo "🔨 Construyendo imagen Docker..."
        docker-compose build
        ;;
    "up")
        echo "🚀 Levantando contenedor..."
        docker-compose up -d
        ;;
    "down")
        echo "🛑 Parando contenedor..."
        docker-compose down
        ;;
    "dump")
        echo "📦 Creando dump de base de datos..."
        docker-compose exec mysql-dump-restore ./dump-docker.sh
        ;;
    "restore")
        if [[ -z "${2:-}" ]]; then
            echo "❌ Error: Debes especificar el archivo de dump"
            echo "Uso: $0 restore <archivo.sql.gz>"
            exit 1
        fi
        echo "📥 Restaurando dump: $2"
        docker-compose exec mysql-dump-restore ./restore-docker.sh "/app/$2"
        ;;
    "shell")
        echo "🐚 Abriendo shell en el contenedor..."
        docker-compose exec mysql-dump-restore bash
        ;;
    "logs")
        echo "📋 Mostrando logs..."
        docker-compose logs -f mysql-dump-restore
        ;;
    "help"|"-h"|"--help"|"")
        show_help
        ;;
    *)
        echo "❌ Comando no reconocido: $1"
        echo ""
        show_help
        exit 1
        ;;
esac