#!/bin/bash 

## Example     ./update_data.sh /home/sam/repos/models/piwind 'OasisLMF/PiWind/1'


LOCAL_PATH=$1
UPLOAD_PATH=$2
#UPLOAD_PATH='OasisLMF/PiWind/1'


SCRIPT_DIR="$(cd $(dirname "$0"); pwd)"
UPLOAD_MODEL_DATA="${SCRIPT_DIR}/scripts/upload_model_data.sh"

MODEL_PATHS="meta-data/model_settings.json oasislmf.json model_data/ keys_data/ tests/inputs/*.csv"
OPTIONAL_MODEL_FILES="meta-data/chunking_configuration.json meta-data/scaling_configuration.json"
files_to_copy=()

for file in $MODEL_PATHS; do
  full_file="${LOCAL_PATH}/$file"
  if ! [ -f "$full_file" ] && ! [ -d "$full_file" ] && ! ls $full_file &> /dev/null; then
    echo "Missing expected file: $full_file"
    exit 1
  fi
  echo "Found file: $full_file"
  files_to_copy+=("$file")
done

for file in $OPTIONAL_MODEL_FILES; do
  full_file="${LOCAL_PATH}/$file"
  if [ -f "$full_file" ] && ! [ -d "$full_file" ]; then
    echo "Found optional file: $full_file"
    files_to_copy+=("$file")
  fi
done




$UPLOAD_MODEL_DATA -c "cp meta-data/* ." -C "$LOCAL_PATH" "$UPLOAD_PATH" ${files_to_copy[@]}
