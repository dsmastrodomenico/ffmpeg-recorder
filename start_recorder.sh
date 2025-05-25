#!/bin/bash

# Ruta al archivo de configuración de cámaras
CAMERAS_FILE="/config/cameras.json"
# Ruta base para el volumen de grabación montado externamente
OUTPUT_BASE_PATH="/recordings"

# Verifica si el archivo de cámaras existe
if [ ! -f "$CAMERAS_FILE" ]; then
  echo "Error: El archivo de configuración de cámaras '$CAMERAS_FILE' no se encontró."
  exit 1
fi

echo "Iniciando grabación de cámaras..."

# Lee el archivo JSON y procesa cada cámara
jq -c '.[]' "$CAMERAS_FILE" | while read camera; do
  NAME=$(echo "$camera" | jq -r '.name')
  RTSP_URL=$(echo "$camera" | jq -r '.rtsp_url')
  OUTPUT_FOLDER=$(echo "$camera" | jq -r '.output_folder')
  SEGMENT_TIME=$(echo "$camera" | jq -r '.segment_time')

  FULL_OUTPUT_PATH="$OUTPUT_BASE_PATH/$OUTPUT_FOLDER"

  echo "Preparando grabación para la cámara: $NAME"
  echo "  URL RTSP: $RTSP_URL"
  echo "  Carpeta de salida: $FULL_OUTPUT_PATH"
  echo "  Tiempo de segmento: $SEGMENT_TIME segundos"

  # Crea la carpeta de salida si no existe
  mkdir -p "$FULL_OUTPUT_PATH"

  # Inicia FFmpeg en segundo plano para cada cámara
  # -i: Entrada (URL RTSP)
  # -c:v copy -c:a copy: Copia los streams de video y audio sin re-codificar (más eficiente)
  # -map 0:v -map 0:a?: Mapea los streams de video y audio (el '?' indica que el audio es opcional)
  # -f segment: Formato de salida por segmentos
  # -segment_time: Duración de cada segmento
  # -strftime 1: Habilita el uso de %Y%m%d%H%M%S en el nombre del archivo
  # -reset_timestamps 1: Resetea las marcas de tiempo para cada segmento
  # -strftime %Y%m%d%H%M%S.mp4: Formato del nombre de archivo (AñoMesDiaHoraMinutoSegundo.mp4)
  # -an: Si solo quieres video, descomenta esta línea y comenta -c:a copy
  ffmpeg -i "$RTSP_URL" \
         -c:v copy -c:a copy \
         -map 0:v -map 0:a? \
         -f segment \
         -segment_time "$SEGMENT_TIME" \
         -strftime 1 \
         -reset_timestamps 1 \
         "$FULL_OUTPUT_PATH/%Y%m%d%H%M%S.mp4" > /dev/null 2>&1 &
  echo "Proceso FFmpeg iniciado para $NAME (PID: $!)"
done

echo "Todos los procesos de grabación de FFmpeg han sido iniciados."
echo "Manteniendo el contenedor en ejecución..."

# Evita que el contenedor se cierre inmediatamente
# Puedes usar un bucle infinito o un comando que se ejecute indefinidamente
tail -f /dev/null