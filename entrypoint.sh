#!/bin/bash

# Ejecuta el script principal como el usuario ffmpeguser
# Esto asegura que FFmpeg y otros procesos corran con permisos limitados.
exec su ffmpeguser -c "/app/start_recorder.sh"