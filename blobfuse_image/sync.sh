#!/bin/sh

set -e

echo "Mounting blobfuse2..."
blobfuse2 mount /mnt/blobfuse \
  --container-name=test \
  --tmp-path=/tmp/blobfuse \
  --log-level=LOG_WARNING

echo "Syncing /mnt/blobfuse to /shared-fs"
cp -r /mnt/blobfuse/. /shared-fs/

inotifywait -m -r -e create --format '%w%f' /shared-fs | while read src_file; do
  echo "$src_file"
  rel_path="${src_file#/shared-fs/}"
  dest="/mnt/blobfuse/$rel_path"
  if [ ! -e "$dest" ]; then
    echo "Copying $src_file to $dest"
    cp "$src_file" "$dest" || echo "Copy failed"
  fi
done &

inotifywait -m -r -e create --format '%w%f' /mnt/blobfuse | while read src_file; do
  echo "$src_file"
  rel_path="${src_file#/mnt/blobfuse/}"
  dest="/shared-fs/$rel_path"
  if [ ! -e "$dest" ]; then
    echo "Copying $src_file to $dest"
    cp "$src_file" "$dest" || echo "Copy failed"
  fi
done &

wait
