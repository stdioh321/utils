#!/bin/bash
# Define variables for GUI
HEIGHT=15
WIDTH=50
PROJECT_KEY=""
PROJECT_DIRECTORY=""
SONARQUBE_PASSWORD=Abc123@Abc123@
# SONARQUBE_PASSWORD=admin

# Function to check if a directory exists
check_directory_exists() {
    if [ ! -d "$1" ]; then
        whiptail --msgbox "The directory '$1' does not exist. Exiting..." 10 50
        exit 1
    fi
}

# Function to check if SonarQube container is running
check_sonarqube_running() {
    if docker ps --filter "name=sonarqube" --filter "status=running" | grep -q "sonarqube"; then
        return 0 # SonarQube is running
    else
        return 1 # SonarQube is not running
    fi
}

# Function to check if necessary tools are installed
check_tools_installed() {
    for tool in docker whiptail curl jq; do
        if ! command -v $tool &>/dev/null; then
            whiptail --msgbox "$tool is not installed. Please install it to proceed." 10 50
            exit 1
        fi
    done
}

# Function to create a new project in SonarQube
create_sonarqube_project() {
    RESPONSE=$(curl -s -u admin:admin -X POST "http://localhost:9000/api/projects/create?name=$PROJECT_KEY&project=$PROJECT_KEY")
    if echo "$RESPONSE" | jq -e '.errors' >/dev/null; then
        echo "Error creating project: $(echo "$RESPONSE" | jq -r '.errors')"
        exit 1
    fi
    echo "Project $PROJECT_KEY created successfully."
}

# Function to retrieve the SonarQube token for the project
get_sonarqube_project_token() {
    RESPONSE=$(curl -X POST -s -u admin:admin "http://localhost:9000/api/user_tokens/generate?name=$PROJECT_KEY")
    TOKEN=$(echo "$RESPONSE" | jq -r '.token')
    if [ -z "$TOKEN" ]; then
        echo "Failed to retrieve token."
        exit 1
    fi
    echo "Token for project $PROJECT_KEY is: $TOKEN"
}

# Check if necessary tools are installed
check_tools_installed

# Ask for Project Key
PROJECT_KEY=$(whiptail --inputbox "Enter the SonarQube Project Key:" $HEIGHT $WIDTH 3>&1 1>&2 2>&3)

if [ -z "$PROJECT_KEY" ]; then
    whiptail --msgbox "Project Key cannot be empty. Exiting..." 10 50
    exit 1
fi

# Ask for Project Directory
PROJECT_DIRECTORY=$(whiptail --title "Project Directory Input" --inputbox "Enter the Project Directory (empty will use the current directory):" $HEIGHT $WIDTH 3>&1 1>&2 2>&3)
if [ -z "$PROJECT_DIRECTORY" ]; then
    PROJECT_DIRECTORY=$(pwd)
fi

# Check if project directory exists
check_directory_exists "$PROJECT_DIRECTORY"

# Define additional variables
SONARQUBE_IMAGE=sonarqube:10.6.0-community
SONAR_SCANNER_IMAGE=sonarsource/sonar-scanner-cli
SONARQUBE_PORT=9000
SONARQUBE_NETWORK=temp_sonar
SONARQUBE_URL=http://localhost:$SONARQUBE_PORT
SONARQUBE_SERVER_HOSTNAME=sonarqube
USER_ID=$(id -u)
GROUP_ID=$(id -g)

# Check if SonarQube is already running
check_sonarqube_running

SONARQUBE_RUNNING=$?

if [ $SONARQUBE_RUNNING -eq 1 ]; then
    # Start SonarQube container if not already running
    echo "Starting SonarQube container..."
    docker network create $SONARQUBE_NETWORK >/dev/null 2>&1 || true
    docker run --rm -d --name sonarqube --hostname $SONARQUBE_SERVER_HOSTNAME -p $SONARQUBE_PORT:$SONARQUBE_PORT --network $SONARQUBE_NETWORK -e SONARQUBE_PASSWORD=$SONARQUBE_PASSWORD $SONARQUBE_IMAGE
else
    # If SonarQube is already running, continue
    echo "SonarQube is already running, proceeding..."
fi

# Wait for SonarQube to be ready
echo "Waiting for SonarQube to be ready..."
while true; do
    STATUS=$(curl -s "$SONARQUBE_URL/api/system/status" | jq -r '.status')
    echo "SonarQube ($SONARQUBE_URL) status: ${STATUS:-UNKNOWN}"
    if [ "$STATUS" == "UP" ]; then
        break
    fi
    echo "Not ready yet, waiting..."
    sleep 5
done

# Create the project in SonarQube
create_sonarqube_project

# Get the SonarQube token
get_sonarqube_project_token

# Run the SonarScanner container
echo "Running SonarScanner..."
# docker run --network $SONARQUBE_NETWORK --rm -v $PROJECT_DIRECTORY:/usr/src --user $USER_ID:$GROUP_ID $SONAR_SCANNER_IMAGE \
#     -Dsonar.projectKey=$PROJECT_KEY \
#     -Dsonar.sources=$PROJECT_DIRECTORY \
#     -Dsonar.host.url="http://$SONARQUBE_SERVER_HOSTNAME:$SONARQUBE_PORT" \
#     -Dsonar.login="$TOKEN"

CONTAINER_ID=$(docker run -d --network $SONARQUBE_NETWORK --rm --user $USER_ID:$GROUP_ID -dit --name sonar-scanner $SONAR_SCANNER_IMAGE bash)
PROJECT_DIRECTORY=$(realpath "$PROJECT_DIRECTORY")
PROJECT_FOLDER=$(basename "$PROJECT_DIRECTORY")

docker cp $PROJECT_DIRECTORY $CONTAINER_ID:/usr/src/$PROJECT_FOLDER

docker exec --user $USER_ID:$GROUP_ID  -w /usr/src/$PROJECT_FOLDER $CONTAINER_ID  sonar-scanner \
    -Dsonar.projectKey=$PROJECT_KEY \
    -Dsonar.host.url="http://$SONARQUBE_SERVER_HOSTNAME:$SONARQUBE_PORT" \
    -Dsonar.token="$TOKEN"
docker rm -f $CONTAINER_ID

echo "###########################################"
echo "SonarQube analysis complete."
echo "###########################################"
echo ""
echo "Go to $SONARQUBE_URL to view the results.\nUsername: admin, Password: $SONARQUBE_PASSWORD"
