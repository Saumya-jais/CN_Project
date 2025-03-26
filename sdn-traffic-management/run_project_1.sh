#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Starting SDN Traffic Management Project Setup${NC}"

# Step 1: Build the ONOS application
echo -e "${GREEN}Building the Traffic Management application...${NC}"
mvn clean package
if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed! Please check the logs above.${NC}"
    exit 1
fi
echo -e "${GREEN}Build successful!${NC}"

# Step 2: Start ONOS if not already running
echo -e "${GREEN}Checking if ONOS is running...${NC}"
onos_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8181/onos/v1/applications -u onos:rocks)

if [ "$onos_status" != "200" ]; then
    echo -e "${YELLOW}ONOS is not running. Starting ONOS...${NC}"
    # Use the ONOS in your local directory
    cd ../onos
    bazel run onos-local -- clean debug &
    echo -e "${YELLOW}Waiting for ONOS to start...${NC}"
    sleep 60  # Wait longer for ONOS to initialize fully
    cd ../sdn-traffic-management
else
    echo -e "${GREEN}ONOS is already running.${NC}"
fi

# Step 3: Install the application to ONOS using Karaf console
echo -e "${GREEN}Installing the Traffic Management application to ONOS...${NC}"
bundle_jar="target/traffic-management-1.0-SNAPSHOT.jar"
if [ -f "$bundle_jar" ]; then
    # Using sshpass to automate the SSH password entry
    # If sshpass is not installed, you'll need to install it with: sudo apt-get install sshpass
    echo -e "${YELLOW}Attempting to install bundle via Karaf console...${NC}"
    sshpass -p karaf ssh -p 8101 -o StrictHostKeyChecking=no karaf@localhost "bundle:install file:$(pwd)/$bundle_jar" || \
    echo -e "${RED}SSH installation failed. Trying REST API...${NC}"
    
    # Alternative: Install via REST API
    echo -e "${YELLOW}Installing via REST API...${NC}"
    curl -u onos:rocks -X POST -HContent-Type:application/octet-stream \
         http://localhost:8181/onos/v1/applications?activate=true \
         --data-binary @$bundle_jar
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Application installation failed!${NC}"
        exit 1
    fi
    echo -e "${GREEN}Application installed successfully!${NC}"
else
    echo -e "${RED}Application JAR not found!${NC}"
    exit 1
fi

# Step 4: Start Mininet with the test topology
echo -e "${GREEN}Starting Mininet with test topology...${NC}"
sudo python3 test_topology.py &
MININET_PID=$!
echo -e "${YELLOW}Mininet started with PID: $MININET_PID${NC}"
sleep 10  # Wait for topology to initialize

# Step 5: Generate traffic for testing
echo -e "${GREEN}Generating test traffic...${NC}"
python3 generate_traffic.py &
TRAFFIC_PID=$!
echo -e "${YELLOW}Traffic generator started with PID: $TRAFFIC_PID${NC}"

echo -e "${GREEN}Setup complete! The application is now monitoring traffic.${NC}"
echo -e "${YELLOW}To check the application logs, use:${NC} ssh -p 8101 karaf@localhost log:tail | grep org.traffic.app"
echo -e "${YELLOW}To access the ONOS GUI, open:${NC} http://localhost:8181/onos/ui"
echo -e "${YELLOW}Username: onos, Password: rocks${NC}"
echo -e "${YELLOW}To stop the test, press Ctrl+C${NC}"

# Wait for user interrupt
trap "echo -e '${RED}Stopping the test...${NC}'; kill $MININET_PID $TRAFFIC_PID 2>/dev/null; sudo mn -c; exit 0" INT
wait
