#!/bin/bash

# Define the log file path
log_file="/var/log/mycompany-update.log"

# Define the maximum file size (in bytes)
max_size=$((50 * 1024 * 1024))  # 50MB

# Check if the log file exists
if [ ! -f "$log_file" ]; then
  echo "Error: Log file '$log_file' not found."
  exit 1
fi

# Get the current file size
file_size=$(stat -c%s "$log_file")

# Check if the file size exceeds the maximum
if [ "$file_size" -gt "$max_size" ]; then
  echo "Log file '$log_file' exceeds the maximum size. Trimming..."

  # Calculate the number of lines to keep (10% of the original)
  line_count=$(wc -l < "$log_file")
  lines_to_keep=$((line_count / 10))

  # Use tail to keep the last 10% of lines and overwrite the file
  tail -n "$lines_to_keep" "$log_file" > "$log_file.tmp" && mv "$log_file.tmp" "$log_file"

  echo "Log file trimmed successfully."

else
  echo "Log file '$log_file' is within the acceptable size."
fi

exit 0
