#!/bin/bash

# Executa o script antes de iniciar o ollama
bash /usr/local/bin/start_ollama.sh

if [ -z "$1" ]; then
  echo "Error: No argument provided."
  exit 1
fi
ARG1=$1

OLLAMA_MODEL="llama3.2"
OLLAMA_COMMAND="ollama run $OLLAMA_MODEL"

$OLLAMA_COMMAND "$ARG1"
