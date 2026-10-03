#!/usr/bin/env bash
# Escapes stdin for the message of a GitHub Actions workflow command, so a
# multi-line log becomes one annotation.
sed -e 's/%/%25/g' -e 's/\r/%0D/g' | awk 'BEGIN { ORS = "%0A" } { print }'
