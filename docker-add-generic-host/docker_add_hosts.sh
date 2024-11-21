#!/bin/bash

# Função para recuperar o IP local
get_ip() {
    ip addr show $(ip route | grep default | awk '{print $5}') | grep inet | grep -v inet6 | awk '{ print $2 }' | cut -d/ -f1
}

# Função para atualizar o /etc/hosts em um container Docker
update_container_hosts() {
    local container_id=$1
    local ip=$2

    # Executando o comando dentro do container para atualizar /etc/hosts
    docker exec -u root "$container_id" bash -c "grep -q '$ip   localnet' /etc/hosts || echo '$ip   localnet' >> /etc/hosts"
}

# Função para atualizar o /etc/hosts no host
update_host_hosts() {
    local ip=$1

    # Verifica se a linha já existe no /etc/hosts e adiciona caso não exista
    grep -q "$ip   localnet" /etc/hosts || echo "$ip   localnet" | sudo tee -a /etc/hosts >/dev/null
}

# Função para copiar o script para /usr/bin/docker_add_hosts e aplicar permissões
install_script() {
    local script_path="/usr/bin/docker_add_hosts"

    if [ ! -f "$script_path" ]; then
        # Copia o script para /usr/bin/docker_add_hosts
        sudo cp "$0" "$script_path"
        # Aplica permissões de execução
        sudo chmod +x "$script_path"
        echo "Script copiado para $script_path e permissão de execução aplicada."
    fi
}

# Função para criar o serviço systemd
create_systemd_service() {
    local service_path="/etc/systemd/system/docker_add_hosts.service"

    if [ ! -f "$service_path" ]; then
        # Criar o arquivo de serviço systemd
        sudo tee "$service_path" >/dev/null <<EOF
[Unit]
Description=Monitor Docker Events and Update Hosts
After=docker.service
Requires=docker.service

[Service]
Type=simple
ExecStart=/usr/bin/docker_add_hosts
Restart=always

[Install]
WantedBy=multi-user.target
EOF
        # Habilitar o serviço
        sudo systemctl daemon-reload
        sudo systemctl enable --now docker_add_hosts.service
        echo "Serviço systemd criado e habilitado."
    fi
}

# Primeiramente, garantir que o script tenha permissão de execução e esteja copiado
install_script

# Criar o serviço systemd (se não existir)
create_systemd_service

# Script que escuta eventos do Docker
docker events --filter 'event=start' | while read event; do
    # Recuperando o IP
    IP_RECUPERADO=$(get_ip)

    # Atualiza o /etc/hosts do host
    update_host_hosts "$IP_RECUPERADO"

    # Iterando sobre os containers Docker em execução
    for container_id in $(docker ps -q); do
        update_container_hosts "$container_id" "$IP_RECUPERADO"
    done

    echo "O IP $IP_RECUPERADO foi adicionado/atualizado em /etc/hosts no host e nos containers."
done
