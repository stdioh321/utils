#!/bin/bash

# Script que escuta eventos do Docker
docker events --filter 'event=start' | while read event
do
    echo "Container iniciado, atualizando /etc/hosts..."
    ./start.sh
done
