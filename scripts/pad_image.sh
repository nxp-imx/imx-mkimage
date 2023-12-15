#!/bin/bash
#set -x

# Compute the sum of all files passed in the command line and pad the last one,
# so that the sum of all files size is aligned on 16 bytes.

_total_size=0

while [[ $# -gt 0 ]]; do
  if [[ ! -f $1 ]]; then
    echo "ERROR: $0: Could not find file $1. Exiting."
    exit 0
  fi

  _file=$1
  _current_file_size="$(wc -c $1 | awk '{print $1}')"
  _total_size=$((_total_size + _current_file_size))
  shift
done

_padded_size="$(((_total_size + 15) & ~15))"
if [[ "${_total_size}" != "${_padded_size}" ]]; then
  _last_file_padded_size=$((_padded_size - (_total_size - _current_file_size)))
  echo "Padding $_file to ${_last_file_padded_size} bytes"
  objcopy -I binary -O binary --pad-to "${_last_file_padded_size}" "${_file}"
fi
