#!/bin/bash

# ============================================================
# Color codes for output
# ============================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================================
# Helper functions
# ============================================================
success() { echo -e "${GREEN}      ✔ $1${NC}"; }
error()   { echo -e "${RED}      ✘ ERROR: $1${NC}"; }
warning() { echo -e "${YELLOW}      ⚠ WARNING: $1${NC}"; }
info()    { echo -e "${BLUE}      ℹ $1${NC}"; }

# ============================================================
# Variables
# ============================================================
TRAINING_DIR="$HOME/training"
TOMCAT_DIR="$TRAINING_DIR/apache-tomcat-9.0.117"
ARKCASE_DIR="$TRAINING_DIR/ArkCase"
DOCKER_SERVICES_DIR="$TRAINING_DIR/ArkCase_Docker_Services_Training"
ARKCASE_TRAINING_DIR="$TRAINING_DIR/ArkCase_Training"
CERT_FILE="$DOCKER_SERVICES_DIR/cert/arkcase.ts"
ENV_FILE="$DOCKER_SERVICES_DIR/env/.env-core"
RUNTIME_SRC="$DOCKER_SERVICES_DIR/minio/arkcase-config/arkcase-runtime.yaml"
RUNTIME_DEST="$ARKCASE_TRAINING_DIR/acm-standard-applications/war/arkcase/target/arkcase-25.09.01-SNAPSHOT/WEB-INF/classes/acm/acm-config-server-repo"
WEBAPPS_DIR="$TOMCAT_DIR/webapps"
WAR_SOURCE="$ARKCASE_TRAINING_DIR/acm-standard-applications/war/arkcase/target/arkcase-25.09.01-SNAPSHOT"

echo ""
echo "============================================================"
echo " ArkCase Pre-Start Setup Script"
echo " Tomcat will be started via VS Code Server Connector"
echo "============================================================"
echo ""

# ============================================================
# STEP 1 - Kill any existing Tomcat/Java processes
# ============================================================
echo -e "${BLUE}[1/8] Stopping any existing Tomcat or Java processes...${NC}"

if pgrep -f catalina > /dev/null 2>&1; then
 pkill -f catalina 2>/dev/null
 warning "Existing Catalina/Tomcat process was running — it has been stopped."
else
 info "No existing Tomcat process found. Continuing."
fi

if pgrep -f "arkcase" > /dev/null 2>&1; then
 pkill -f "arkcase" 2>/dev/null
 warning "Existing ArkCase process was running — it has been stopped."
fi

sleep 3

# Verify ports are now free
for PORT in 8005 8080 8843 1099; do
 if sudo lsof -i :$PORT > /dev/null 2>&1; then
   error "Port $PORT is still in use after killing processes!"
   info "Run this to find what is using it: sudo lsof -i :$PORT"
   info "Then kill it with: sudo kill -9 <PID>"
   exit 1
 fi
done
success "All ports 8005, 8080, 8843, 1099 are free."

# ============================================================
# STEP 2 - Verify required files and folders exist
# ============================================================
echo ""
echo -e "${BLUE}[2/8] Verifying required files and folders...${NC}"

# Check and install xmllint if not installed
info "Checking if xmllint is installed..."
if ! command -v xmllint > /dev/null 2>&1; then
 warning "xmllint is not installed. Installing now..."
 sudo apt-get install -y libxml2-utils > /dev/null 2>&1
 if ! command -v xmllint > /dev/null 2>&1; then
   error "Failed to install xmllint!"
   info "Try manually: sudo apt-get install libxml2-utils"
   exit 1
 fi
 success "xmllint installed successfully."
else
 success "xmllint is already installed."
fi

# Check Tomcat directory
if [ ! -d "$TOMCAT_DIR" ]; then
 error "Tomcat directory not found at: $TOMCAT_DIR"
 info "Make sure Tomcat 9.0.117 is extracted in your training folder."
 exit 1
fi
success "Tomcat found at $TOMCAT_DIR"

# Check Tomcat catalina.sh is executable
if [ ! -x "$TOMCAT_DIR/bin/catalina.sh" ]; then
 error "catalina.sh is not executable!"
 info "Fix it by running: chmod +x $TOMCAT_DIR/bin/catalina.sh"
 exit 1
fi
success "catalina.sh is executable."

# Check server.xml exists and is valid
if [ ! -f "$TOMCAT_DIR/conf/server.xml" ]; then
 error "server.xml not found at $TOMCAT_DIR/conf/server.xml"
 info "Tomcat configuration is missing or corrupted."
 exit 1
fi
if ! xmllint --noout "$TOMCAT_DIR/conf/server.xml" 2>/dev/null; then
 error "server.xml contains a syntax error!"
 info "Run this to see the exact line and error:"
 info "xmllint $TOMCAT_DIR/conf/server.xml"
 exit 1
fi
success "server.xml found and is valid."

# Check certificate file
if [ ! -f "$CERT_FILE" ]; then
 error "SSL Certificate not found at: $CERT_FILE"
 info "ArkCase cannot start without the SSL certificate."
 info "Make sure ArkCase_Docker_Services_Training is set up correctly."
 exit 1
fi
success "SSL Certificate found."

# Check ENV file
if [ ! -f "$ENV_FILE" ]; then
 error "ENV file not found at: $ENV_FILE"
 info "ArkCase cannot start without the .env-core file."
 info "Make sure ArkCase_Docker_Services_Training is set up correctly."
 exit 1
fi
success "ENV file found."

# Check Docker Services directory
if [ ! -d "$DOCKER_SERVICES_DIR" ]; then
 error "Docker Services directory not found at: $DOCKER_SERVICES_DIR"
 info "Make sure ArkCase_Docker_Services_Training is in your training folder."
 exit 1
fi
success "Docker Services directory found."

# ============================================================
# STEP 3 - Check Docker is running
# ============================================================
echo ""
echo -e "${BLUE}[3/8] Checking Docker and required services...${NC}"

if ! docker info > /dev/null 2>&1; then
 error "Docker is not running!"
 info "Start Docker with: sudo service docker start"
 info "ArkCase depends on Docker for MySQL, ActiveMQ, and other services."
 exit 1
fi
success "Docker is running."

# Check key Docker containers are up
REQUIRED_CONTAINERS=("mysql" "activemq" "alfresco")
for CONTAINER in "${REQUIRED_CONTAINERS[@]}"; do
 if docker ps --format '{{.Names}}' | grep -qi "$CONTAINER"; then
   success "Docker container '$CONTAINER' is running."
 else
   warning "Docker container '$CONTAINER' does not appear to be running."
   info "Run: cd $DOCKER_SERVICES_DIR && docker-compose up -d"
 fi
done

# ============================================================
# STEP 4 - Check network connectivity
# ============================================================
echo ""
echo -e "${BLUE}[4/8] Checking network connectivity...${NC}"

# Check acm-arkcase in hosts file
if grep -q "acm-arkcase" /etc/hosts; then
 success "acm-arkcase found in /etc/hosts."
else
 warning "acm-arkcase not found in /etc/hosts. Adding it now..."
 echo "127.0.0.1   acm-arkcase" | sudo tee -a /etc/hosts > /dev/null
 if grep -q "acm-arkcase" /etc/hosts; then
   success "acm-arkcase successfully added to /etc/hosts."
 else
   error "Failed to add acm-arkcase to /etc/hosts!"
   info "Try manually: echo '127.0.0.1 acm-arkcase' | sudo tee -a /etc/hosts"
   exit 1
 fi
fi

# Check acm-arkcase resolves
if ping -c 1 acm-arkcase > /dev/null 2>&1; then
 success "acm-arkcase resolves correctly."
else
 error "acm-arkcase does not resolve even though it is in /etc/hosts!"
 info "Check your /etc/hosts file: cat /etc/hosts | grep arkcase"
 exit 1
fi

# ============================================================
# STEP 5 - Create ~/.arkcase/custom folder
# ============================================================
echo ""
echo -e "${BLUE}[5/8] Checking ~/.arkcase/custom folder...${NC}"

mkdir -p ~/.arkcase/custom
if [ -d "$HOME/.arkcase/custom" ]; then
 success "~/.arkcase/custom folder exists."
else
 error "Failed to create ~/.arkcase/custom!"
 info "Try manually: mkdir -p ~/.arkcase/custom"
 exit 1
fi

# ============================================================
# STEP 6 - Load ENV file variables
# ============================================================
echo ""
echo -e "${BLUE}[6/8] Loading environment variables from .env-core...${NC}"

set -a
source "$ENV_FILE"
set +a

# Verify key variables loaded
if [ -z "$ARKCASE_JDBC_PLATFORM" ]; then
 error "ENV variables did not load correctly!"
 info "ARKCASE_JDBC_PLATFORM is empty — check your .env-core file."
 info "File location: $ENV_FILE"
 exit 1
fi
success "ENV variables loaded. ARKCASE_JDBC_PLATFORM=$ARKCASE_JDBC_PLATFORM"

# ============================================================
# STEP 7 - Copy Runtime File
# ============================================================
echo ""
echo -e "${BLUE}[7/8] Copying arkcase-runtime.yaml...${NC}"

if [ ! -f "$RUNTIME_SRC" ]; then
 error "Runtime source file not found at: $RUNTIME_SRC"
 info "Check that your minio arkcase-config folder is set up correctly."
 exit 1
fi

mkdir -p "$RUNTIME_DEST"
if [ ! -d "$RUNTIME_DEST" ]; then
 error "Could not create runtime destination directory!"
 info "Destination: $RUNTIME_DEST"
 info "Make sure the WAR has been built first: mvn clean package -DskipTests"
 exit 1
fi

cp -f "$RUNTIME_SRC" "$RUNTIME_DEST"
if [ $? -eq 0 ]; then
 success "Runtime file copied successfully."
else
 error "Failed to copy runtime file!"
 info "Source: $RUNTIME_SRC"
 info "Destination: $RUNTIME_DEST"
 exit 1
fi

# ============================================================
# STEP 8 - Deploy WAR to Tomcat webapps
# ============================================================
echo ""
echo -e "${BLUE}[8/8] Deploying ArkCase WAR to Tomcat webapps...${NC}"

if [ ! -d "$WAR_SOURCE" ]; then
 error "Exploded WAR not found at: $WAR_SOURCE"
 info "You need to build the project first. Run:"
 info "cd $ARKCASE_DIR && mvn clean package -DskipTests"
 exit 1
fi

if [ -d "$WEBAPPS_DIR/arkcase" ]; then
 warning "Old deployment found — removing it..."
 rm -rf "$WEBAPPS_DIR/arkcase"
 if [ -d "$WEBAPPS_DIR/arkcase" ]; then
   error "Failed to remove old deployment!"
   info "Try manually: rm -rf $WEBAPPS_DIR/arkcase"
   exit 1
 fi
 success "Old deployment removed."
fi

cp -r "$WAR_SOURCE" "$WEBAPPS_DIR/arkcase"
if [ $? -eq 0 ]; then
 success "ArkCase deployed to $WEBAPPS_DIR/arkcase"
else
 error "Failed to deploy ArkCase WAR!"
 info "Source: $WAR_SOURCE"
 info "Destination: $WEBAPPS_DIR/arkcase"
 exit 1
fi

# ============================================================
# ALL DONE
# ============================================================
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN} ✔ All setup steps completed successfully!${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo -e "${BLUE} Next Steps:${NC}"
echo "  1. Go to the SERVERS panel in VS Code"
echo "  2. Right-click Tomcat 9.x and click Start"
echo "  3. Watch the OUTPUT tab for logs"
echo "  4. Once you see 'Server startup in [xxxx] milliseconds'"
echo "     open your browser and go to:"
echo ""
echo -e "${GREEN}     https://acm-arkcase:8843/arkcase${NC}"
echo ""
echo "     Username: arkcase-admin@arkcase.org"
echo "     Password: arkcase"
echo ""
