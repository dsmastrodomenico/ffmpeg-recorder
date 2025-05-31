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
jq -c '.[]' "$CAMERAS_FILE" | while read camera_config; do
  # Extrae los parámetros de configuración de la cámara
  NAME=$(echo "$camera_config" | jq -r '.name')
  RTSP_URL_TEMPLATE=$(echo "$camera_config" | jq -r '.rtsp_url_template')
  OUTPUT_FOLDER=$(echo "$camera_config" | jq -r '.output_folder')
  SEGMENT_TIME=$(echo "$camera_config" | jq -r '.segment_time')
  VIDEO_CODEC=$(echo "$camera_config" | jq -r '.video_codec')
  PRESET=$(echo "$camera_config" | jq -r '.preset')
  CRF=$(echo "$camera_config" | jq -r '.crf')
  SCALE_RES=$(echo "$camera_config" | jq -r '.scale_res')
  OUTPUT_FORMAT=$(echo "$camera_config" | jq -r '.output_format')
  FILENAME_PATTERN=$(echo "$camera_config" | jq -r '.filename_pattern')
  AUDIO_ENABLED=$(echo "$camera_config" | jq -r '.audio_enabled')

  # Construye la URL RTSP sustituyendo las variables de entorno
  # envsubst solo reemplaza si la variable de entorno existe.
  RTSP_URL=$(echo "$RTSP_URL_TEMPLATE" | envsubst)

  # Verifica si la URL se construyó correctamente
  if [[ "$RTSP_URL" == *'{{'* ]]; then
    echo "Advertencia: La URL RTSP para '$NAME' contiene placeholders no sustituidos. Revisa tus variables de entorno."
    echo "URL sin sustituir: $RTSP_URL"
    continue # Salta a la siguiente cámara si la URL no está completa
  fi

  FULL_OUTPUT_PATH="$OUTPUT_BASE_PATH/$OUTPUT_FOLDER"
  FINAL_FILENAME="$FULL_OUTPUT_PATH/$FILENAME_PATTERN"

  echo "Preparando grabación para la cámara: $NAME"
  echo "  URL RTSP (parcialmente oculta): rtsp://[usuario]:[password]@${RTSP_URL#*@}"
  echo "  Carpeta de salida: $FULL_OUTPUT_PATH"
  echo "  Tiempo de segmento: $SEGMENT_TIME segundos"
  echo "  Códec de video: $VIDEO_CODEC"
  echo "  Preset/CRF: $PRESET / $CRF"
  echo "  Resolución de escala: $SCALE_RES"
  echo "  Formato de salida: $OUTPUT_FORMAT"
  echo "  Patrón de nombre de archivo: $FILENAME_PATTERN"
  echo "  Audio habilitado: $AUDIO_ENABLED"

  # Crea la carpeta de salida si no existe
  mkdir -p "$FULL_OUTPUT_PATH"

  # Construye los parámetros de audio condicionalmente
  AUDIO_PARAMS=""
  if [ "$AUDIO_ENABLED" = "false" ]; then
    AUDIO_PARAMS="-an" # Sin audio
  else
    AUDIO_PARAMS="-c:a aac -b:a 128k" # Ejemplo: Codificar audio a AAC
  fi

  # Inicia FFmpeg en segundo plano para cada cámara
  # Nota: El orden de algunos parámetros en FFmpeg es importante.
  # Los parámetros de entrada (-rtsp_transport, -i, -buffer_size) deben ir antes de -i.
  # Los parámetros de salida (-c:v, -preset, -crf, -vf, -f segment, etc.) deben ir después de -i y antes del archivo de salida.
  ffmpeg -rtsp_transport tcp \
         -buffer_size 4096k \
         -i "$RTSP_URL" \
         -c:v "$VIDEO_CODEC" \
         -preset "$PRESET" \
         -crf "$CRF" \
         $AUDIO_PARAMS \
         -vf "scale=$SCALE_RES" \
         -f segment \
         -segment_time "$SEGMENT_TIME" \
         -strftime 1 \
         -segment_format "$OUTPUT_FORMAT" \
         -reset_timestamps 1 \
         "$FINAL_FILENAME" > /dev/null 2>&1 &
  echo "Proceso FFmpeg iniciado para $NAME (PID: $!)"
done

echo "Todos los procesos de grabación de FFmpeg han sido iniciados."
echo "Manteniendo el contenedor en ejecución..."

# Evita que el contenedor se cierre inmediatamente
tail -f /dev/null