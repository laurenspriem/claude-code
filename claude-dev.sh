#!/bin/bash
set -e

# Configuration
CONTAINER_NAME="claude-code-dev"
IMAGE_NAME="claude-code-sandbox:latest"
WORKSPACE_DIR="$(pwd)"

# Build arguments
TZ="${TZ:-Asia/Kolkata}"
CLAUDE_CODE_VERSION="latest"
GIT_DELTA_VERSION="0.18.2"
ZSH_IN_DOCKER_VERSION="1.2.0"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to check ADB setup
check_adb_setup() {
    if command -v adb >/dev/null 2>&1; then
        if ! timeout 1 bash -c "cat < /dev/null > /dev/tcp/172.17.0.1/5037" 2>/dev/null; then
            echo ""
            echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo -e "${YELLOW}Android Emulator Support:${NC}"
            echo "ADB server not detected on host."
            echo "To enable Android emulator access, run on your HOST:"
            echo -e "${BLUE}  adb kill-server && adb -a nodaemon server start${NC}"
            echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
            echo ""
        fi
    fi
}

# Parse command line arguments
REBUILD=false
FIREWALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --rebuild|-r)
            REBUILD=true
            shift
            ;;
        --firewall)
            FIREWALL=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --rebuild, -r : Force rebuild of the container"
            echo "  --firewall    : Enable strict network firewall (disabled by default)"
            echo "  --help, -h    : Show this help message"
            echo ""
            echo "By default, the firewall is DISABLED for unrestricted network access."
            echo "Use --firewall to enable the restrictive firewall."
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--rebuild|-r] [--firewall] [--help|-h]"
            echo "Run '$0 --help' for more information."
            exit 1
            ;;
    esac
done

echo -e "${BLUE}Claude Code Dev Container${NC}"
echo "========================="

# Function to build the image
build_image() {
    echo -e "${GREEN}Building Docker image...${NC}"
    docker build \
        --build-arg TZ="${TZ}" \
        --build-arg CLAUDE_CODE_VERSION="${CLAUDE_CODE_VERSION}" \
        --build-arg GIT_DELTA_VERSION="${GIT_DELTA_VERSION}" \
        --build-arg ZSH_IN_DOCKER_VERSION="${ZSH_IN_DOCKER_VERSION}" \
        -t ${IMAGE_NAME} \
        -f .devcontainer/Dockerfile \
        .devcontainer/
}

# Function to run new container
run_container() {
    # Create volume for bash history if it doesn't exist
    docker volume create claude-code-bashhistory 2>/dev/null || true

    # Ensure directories exist
    mkdir -p ~/devcontainer_claude_config
    mkdir -p ~/dev_wild

    # Build the startup command based on firewall flag
    if [ "$FIREWALL" = true ]; then
        echo -e "${YELLOW}Firewall enabled - network access will be restricted${NC}"
        STARTUP_CMD="sudo chown -R node:node /home/node/.claude && sudo /usr/local/bin/init-firewall.sh && /usr/local/bin/setup-adb.sh"
    else
        echo -e "${GREEN}Firewall disabled - full network access${NC}"
        STARTUP_CMD="sudo chown -R node:node /home/node/.claude && /usr/local/bin/setup-adb.sh"
    fi

    echo -e "${GREEN}Starting new container...${NC}"
    docker run -it \
        --name ${CONTAINER_NAME} \
        --cap-add=NET_ADMIN \
        --cap-add=NET_RAW \
        --mount source=claude-code-bashhistory,target=/commandhistory,type=volume \
        --mount source="${HOME}/devcontainer_claude_config",target=/home/node/.claude,type=bind,consistency=cached \
        --mount source="${HOME}/dev_wild",target=/home/laurens/dev_wild,type=bind,consistency=cached \
        --mount source="${WORKSPACE_DIR}",target=/workspace,type=bind,consistency=delegated \
        -w /home/laurens/dev_wild \
        -e NODE_OPTIONS="--max-old-space-size=4096" \
        -e CLAUDE_CONFIG_DIR="/home/node/.claude" \
        -e POWERLEVEL9K_DISABLE_GITSTATUS="true" \
        ${IMAGE_NAME} \
        /bin/bash -c "${STARTUP_CMD} && if ! timeout 1 bash -c 'cat < /dev/null > /dev/tcp/172.17.0.1/5037' 2>/dev/null && command -v adb >/dev/null 2>&1; then echo ''; echo -e '\033[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m'; echo -e '\033[1;33mAndroid Emulator Support:\033[0m'; echo 'ADB server not detected on host.'; echo 'To enable Android emulator access, run on your HOST:'; echo -e '\033[0;34m  adb kill-server && adb -a nodaemon server start\033[0m'; echo -e '\033[1;33m━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\033[0m'; echo ''; fi && exec /bin/zsh"
}

# Check if user wants to rebuild
if [ "$REBUILD" = true ]; then
    echo -e "${YELLOW}Rebuild requested...${NC}"
    if [ "$(docker ps -aq -f name=^${CONTAINER_NAME}$)" ]; then
        echo "Stopping and removing existing container..."
        docker stop ${CONTAINER_NAME} 2>/dev/null || true
        docker rm ${CONTAINER_NAME} 2>/dev/null || true
    fi
    build_image
    run_container
    exit 0
fi

# Check if container exists
if [ "$(docker ps -aq -f name=^${CONTAINER_NAME}$)" ]; then
    # Container exists - check if it's running
    if [ "$(docker ps -q -f name=^${CONTAINER_NAME}$)" ]; then
        # Container is running - just attach
        echo -e "${GREEN}Attaching to running container...${NC}"
        docker exec -it ${CONTAINER_NAME} /bin/zsh
    else
        # Container exists but stopped - start and attach
        echo -e "${YELLOW}Starting stopped container...${NC}"
        docker start -i ${CONTAINER_NAME}
    fi
else
    # Container doesn't exist - check if image exists
    if [[ "$(docker images -q ${IMAGE_NAME} 2> /dev/null)" == "" ]]; then
        # Image doesn't exist - build it
        build_image
    else
        echo -e "${GREEN}Using existing image...${NC}"
    fi
    # Run new container
    run_container
fi