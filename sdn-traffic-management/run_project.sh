#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color


#sudo apt install openvswitch-switch -y
# sudo apt install genome-terminal
# sudo apt install sshpass -y

echo -e "${YELLOW}Starting SDN Traffic Management Project Setup${NC}"

# Step 1: Build the ONOS application
echo -e "${GREEN}Building the Traffic Management application...${NC}"
mvn clean package
if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed! Please check the logs above.${NC}"
    exit 1
fi
echo -e "${GREEN}Build successful!${NC}"

read -p "Press Enter to proceed to Step 2 (Checking ONOS)..."
# -----------------------------------------------------------------------------

# Step 2: Start ONOS if not already running
echo -e "${GREEN}Checking if ONOS is running...${NC}"
onos_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8181/onos/v1/applications -u onos:rocks)

if [ "$onos_status" != "200" ]; then
    echo -e "${YELLOW}ONOS is not running. Starting ONOS...${NC}"
    cd ../onos
    bazel run onos-local -- clean debug &
    echo -e "${YELLOW}Waiting for ONOS to start...${NC}"
    sleep 60
    cd ../sdn-traffic-management
    onos_status=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:8181/onos/v1/applications -u onos:rocks)
    if [ "$onos_status" == "200" ]; then
        echo -e "${GREEN}ONOS started successfully!${NC}"
    else
        echo -e "${RED}ONOS failed to start. Check logs for details.${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}ONOS is already running.${NC}"
fi

read -p "Press Enter to proceed to Step 3 (Checking and Starting OVS)..."
# -----------------------------------------------------------------------------
#  Ensure OVS is running
echo -e "${GREEN}Checking if Open vSwitch (OVS) is running...${NC}"
if ! sudo systemctl is-active --quiet openvswitch-switch; then
    echo -e "${YELLOW}OVS is not running. Starting OVS...${NC}"
    sudo systemctl start openvswitch-switch
    sleep 5
fi

# Verify OVS database connection
if ! sudo ovs-vsctl show > /dev/null 2>&1; then
    echo -e "${RED}OVS database connection failed! Restarting OVS...${NC}"
    sudo systemctl restart openvswitch-switch
    sleep 5
    if ! sudo ovs-vsctl show > /dev/null 2>&1; then
        echo -e "${RED}Failed to start OVS! Please check installation.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}OVS is running successfully!${NC}"

# -----------------------------------------------------------------------------

read -p "Press Enter to proceed to Step 3 (Installing Application)..."

# Step 3: Install the application to ONOS
echo -e "${GREEN}Installing the Traffic Management application to ONOS...${NC}"
bundle_jar="target/traffic-management-1.0-SNAPSHOT.jar"
if [ -f "$bundle_jar" ]; then
    echo -e "${YELLOW}Installing via Karaf console...${NC}"
    sshpass -p karaf ssh -p 8101 -o StrictHostKeyChecking=no karaf@localhost "bundle:install file:$(pwd)/$bundle_jar" || \
    echo -e "${RED}SSH installation failed. Trying REST API...${NC}"
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

read -p "Press Enter to proceed to Step 4 (Starting Mininet in another terminal)..."
# -----------------------------------------------------------------------------

# Step 4: Start Mininet in a new terminal
echo -e "${GREEN}Starting Mininet in a separate terminal...${NC}"
gnome-terminal -- bash -c "sudo python3 test_topology.py; exec bash" &
sleep 10  # Allow Mininet to start

# Verify Mininet and ONOS connection
echo -e "${YELLOW}Checking if ONOS is listening on port 6653...${NC}"
if ! sudo netstat -tulnp | grep -q ":6653 .*LISTEN"; then
    echo -e "${RED}ONOS is not running or not listening on port 6653!${NC}"
    echo -e "${YELLOW}Starting ONOS service...${NC}"
    onos-service start
    sleep 10
fi

TRIES=10
while [ $TRIES -gt 0 ]; do
    onos_switches=$(curl -s -u onos:rocks http://localhost:8181/onos/v1/devices | grep -o "available":true | wc -l)
    if [ "$onos_switches" -gt 0 ]; then
        echo -e "${GREEN}All switches are connected to ONOS.${NC}"
        break
    fi
    echo -e "${YELLOW}Waiting for switches to appear in ONOS... (${TRIES} retries left)${NC}"
    sleep 5
    ((TRIES--))
done

if [ "$onos_switches" -eq 0 ]; then
    echo -e "${RED}Switches did not connect to ONOS! Attempting to fix...${NC}"
    sudo ovs-vsctl del-controller s1 s2 s3 s4
    sleep 2
    sudo ovs-vsctl set-controller s1 tcp:127.0.0.1:6653
    sudo ovs-vsctl set-controller s2 tcp:127.0.0.1:6653
    sudo ovs-vsctl set-controller s3 tcp:127.0.0.1:6653
    sudo ovs-vsctl set-controller s4 tcp:127.0.0.1:6653
    sleep 5
    onos_switches=$(curl -s -u onos:rocks http://localhost:8181/onos/v1/devices | grep -o "available":true | wc -l)
    if [ "$onos_switches" -gt 0 ]; then
        echo -e "${GREEN}Switches successfully connected to ONOS after retry.${NC}"
    else
        echo -e "${RED}Failed to connect switches to ONOS! Check ONOS logs.${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}Mininet and ONOS are successfully set up!${NC}"

read -p "Press Enter to proceed to Step 5 (Generating Traffic in another terminal)..."
# -----------------------------------------------------------------------------

echo -e "${GREEN}Starting Traffic Generation in a new terminal...${NC}"
gnome-terminal -- bash -c "sudo python3 generate_traffic.py; exec bash" &

echo -e "${GREEN}Setup complete! The application is now monitoring traffic.${NC}"
