# Usa una imagen base ligera con Debian, que es compatible con FFmpeg
FROM debian:stable-slim

# Instala FFmpeg y otras utilidades necesarias
# -y para no pedir confirmación
# --no-install-recommends para evitar instalar paquetes innecesarios
RUN apt-get update && apt-get install -y ffmpeg rsync jq nano dnsutils openssl && \
    rm -rf /var/lib/apt/lists/*

# Crea un usuario no-root para ejecutar FFmpeg (mejora la seguridad)
RUN useradd -ms /bin/bash ffmpeguser

# Crea el directorio de trabajo
WORKDIR /app

# Copia los scripts y el archivo de configuración de cámaras
COPY start_recorder.sh .
COPY entrypoint.sh .

# Otorga permisos de ejecución a los scripts
RUN chmod +x start_recorder.sh entrypoint.sh

# Cambia el propietario de los archivos al usuario ffmpeguser
RUN chown -R ffmpeguser:ffmpeguser /app

# Define el punto de entrada que ejecutará el script principal como el usuario ffmpeguser
ENTRYPOINT ["./entrypoint.sh"]

# Puerto opcional si necesitas algún tipo de interfaz web o API en el futuro
# Si no lo necesitas, puedes omitirlo
# EXPOSE 8080