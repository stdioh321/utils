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

# Recuperando o IP
IP_RECUPERADO=$(get_ip)

# Atualiza o /etc/hosts do host
update_host_hosts "$IP_RECUPERADO"

# Iterando sobre os containers Docker em execução
for container_id in $(docker ps -q); do
  update_container_hosts "$container_id" "$IP_RECUPERADO"
done

echo "O IP $IP_RECUPERADO foi adicionado/atualizado em /etc/hosts no host e nos containers."
