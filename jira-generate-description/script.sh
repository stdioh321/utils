#!/bin/bash

# Função para verificar se o comando está disponível
check_command() {
    local command=$1
    if ! command -v "$command" &>/dev/null; then
        echo "O comando '$command' não está instalado. Por favor, instale-o antes de continuar."
        exit 1
    fi
}

# Função para verificar se o processo está em execução
check_process() {
    local process=$1
    pgrep -x "$process" >/dev/null || {
        echo "O processo '$process' não está em execução."
        exit 1
    }
}

# Função para verificar e obter credenciais do JIRA
check_jira_credentials() {
    local config_file=$1
    local jira_url=$2

    if [ ! -f "$config_file" ]; then
        echo "O arquivo de configuração $config_file não existe."
        echo "Digite o seu usuário, token e a URL do JIRA:"
        read -p "URL do JIRA (ex: https://suaempresa.atlassian.net): " JIRA_URL
        JIRA_URL="${JIRA_URL%/}"  # Removes trailing slash, if any
        read -p "Usuário: " JIRA_USER
        read -p "Token: " JIRA_TOKEN

        # Verificar se o JIRA_USER e JIRA_TOKEN são válidos
        if ! curl --fail -s -u "$JIRA_USER:$JIRA_TOKEN" -H "Content-Type: application/json" "$JIRA_URL/rest/api/3/myself" > /dev/null; then
            echo "Erro: O usuário ou token informados são inválidos."
            if [ -f "$config_file" ]; then
                rm "$config_file"
            fi
            exit 1
        fi

        # Gravar no arquivo de configuração
        echo "JIRA_URL=$JIRA_URL" > "$config_file"
        echo "JIRA_USER=$JIRA_USER" >> "$config_file"
        echo "JIRA_TOKEN=$JIRA_TOKEN" >> "$config_file"
    fi

    # Ler do arquivo de configuração
    source "$config_file"
}

# Função para verificar se o modelo ollama está instalado
check_ollama_model() {
    local model=$1
    if [ -z "$(ollama list | grep "$model")" ]; then
        echo "O modelo ollama '$model' não está instalado."
        echo "Instalando...."
        ollama pull "$model"
    fi
}

# Função para mostrar o loading enquanto o ollama está processando
loading() {
    local pid=$1
    local delay=0.15
    local spinstr='|/-\'
    local temp
    while kill -0 "$pid" 2>/dev/null; do
        temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r"
    done
    printf "    \r" # Limpa a linha ao final
}
# Executa o script antes de iniciar o ollama
bash /usr/local/bin/start_ollama.sh

# Verifica comandos essenciais
check_command "ollama"
check_command "curl"

# Verifica se o processo do ollama está em execução
check_process "ollama"

# Verifica se o parâmetro ISSUE_ID foi fornecido
if [ -z "$1" ]; then
    echo "Por favor, forneça o ISSUE_ID como argumento."
    exit 1
fi

# Definir variáveis
OLLAMA_MODEL="llama3.2"
ISSUE_ID=$1
CONFIG_FILE=~/.config/jira-generate-description.config

# Verifica credenciais e URL JIRA
check_jira_credentials "$CONFIG_FILE"
echo "Arquivo de configuração verificado: $CONFIG_FILE"
source "$CONFIG_FILE"

# Verifica se o modelo ollama está instalado
check_ollama_model "$OLLAMA_MODEL"

# Carrega JIRA_USER, JIRA_TOKEN e JIRA_URL
if [ -z "$JIRA_USER" ] || [ -z "$JIRA_TOKEN" ] || [ -z "$JIRA_URL" ]; then
    echo "As variáveis de ambiente JIRA_USER, JIRA_TOKEN ou JIRA_URL não estão definidas."
    exit 1
fi

# Pega os dados da issue do JIRA via API
JIRA_DATA=$(curl -s -u "$JIRA_USER:$JIRA_TOKEN" -H "Content-Type: application/json" "$JIRA_URL/rest/api/2/issue/$ISSUE_ID")

# Verifica se a consulta retornou resultados válidos
if [ -z "$JIRA_DATA" ]; then
    echo "Erro ao recuperar dados do JIRA para o ISSUE_ID $ISSUE_ID."
    exit 1
fi

# Extraí os dados de título e descrição
TITLE=$(echo "$JIRA_DATA" | jq -r '.fields.summary')
DESCRIPTION=$(echo "$JIRA_DATA" | jq -r '.fields.description')

# Gera a descrição detalhada do JIRA com o título e descrição fornecidos
echo "Gerando descrição detalhada da task '$ISSUE_ID: $TITLE'"

# Define o comando ollama para gerar a descrição detalhada
OLLAMA_COMMAND="ollama run $OLLAMA_MODEL"
OLLAMA_INPUT="""
Gerar em markdown uma descrição mais detalhada de task do Jira
* deve adicionar uma seção com BDD (min: 3)
* deve adicionar seção de Criterios de aceite (min: 3)
    * Criterios padrão
        * yarn build deve executar sem erros
        * yarn test deve executar sem erros
        * Se possuir novas variaveis de ambiente, devem estar descritas na task
        * Se outra task for necessaria para a conclusão da task, a mesma deve ser criada e referenciada
        * Se faltar informações para conclusão da task, quem possuir o conhecimento, deve ser informado e citado na task
* json com dados da task: '{ "title": \"$TITLE\", "description": \"$DESCRIPTION\" }'
"""

# Cria um arquivo temporário para armazenar o output
TEMP_FILE=$(mktemp /tmp/ollama_output.XXXXXX.$(date +%s%N))

# Executa o comando ollama e grava a saída no arquivo temporário
$OLLAMA_COMMAND "$OLLAMA_INPUT" > "$TEMP_FILE" &
OLLAMA_PID=$!

# Chama a função de loading enquanto espera o processo terminar
loading $OLLAMA_PID

# Espera o processo do ollama terminar
wait $OLLAMA_PID

# Lê o conteúdo do arquivo temporário e exibe
DESCRIPTION_DETAIL=$(cat "$TEMP_FILE")
echo "$DESCRIPTION_DETAIL"

# Deleta o arquivo temporário após o uso
rm "$TEMP_FILE"
