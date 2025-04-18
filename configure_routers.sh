#!/bin/bash

# Script to automate FRR installation and basic setup on router containers

# --- Configuration ---
# !! IMPORTANT: Verify these container names match the output of 'sudo docker ps' !!
R1="pa3-r1-1"
R2="pa3-r2-1"
R3="pa3-r3-1"
R4="pa3-r4-1"
# --- End Configuration ---

ROUTERS=("$R1" "$R2" "$R3" "$R4")
FRR_PACKAGES="frr frr-pythontools"
PREREQ_PACKAGES="curl gnupg lsb-release vim nano" # Added editors

# --- FRR Installation Function ---
install_frr() {
    local container_name=$1
    echo "--- Processing $container_name ---"
    # Update package list and install prerequisites
    sudo docker exec -it "$container_name" sudo apt update
    sudo docker exec -it "$container_name" sudo apt -y install $PREREQ_PACKAGES
    # Add FRR key
    sudo docker exec -it "$container_name" bash -c 'curl -s https://deb.frrouting.org/frr/keys.gpg | sudo tee /usr/share/keyrings/frrouting.gpg > /dev/null'
    # Add FRR repository
    sudo docker exec -it "$container_name" bash -c 'FRRVER="frr-stable"; echo "deb [signed-by=/usr/share/keyrings/frrouting.gpg] https://deb.frrouting.org/frr $(lsb_release -s -c) $FRRVER" | sudo tee /etc/apt/sources.list.d/frr.list'
    # Update package list again and install FRR
    sudo docker exec -it "$container_name" sudo apt update
    sudo docker exec -it "$container_name" sudo apt -y install $FRR_PACKAGES
    echo "--- Done installing FRR on $container_name ---"
}

# --- Basic FRR Configuration Function ---
configure_frr_basic() {
    local container_name=$1
    echo "--- Basic config for $container_name ---"
    # Enable ospfd=yes using sed (non-interactive edit)
    sudo docker exec -it "$container_name" sudo sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons
    # Restart FRR service
    sudo docker exec -it "$container_name" sudo service frr restart
    echo "--- Done basic FRR config on $container_name ---"
}

# --- Main Execution ---

# Install FRR on all routers
echo ">>> Installing FRR on all routers..."
for router in "${ROUTERS[@]}"; do
    install_frr "$router"
done
echo ">>> FRR Installation complete."

# Perform basic configuration (enable ospfd, restart frr)
echo ">>> Performing basic FRR configuration..."
for router in "${ROUTERS[@]}"; do
    configure_frr_basic "$router"
done
echo ">>> Basic FRR configuration complete."


# --- OSPF Specific Configuration Notes ---
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "NOTE: OSPF specific configuration (router-id, network commands, costs)"
echo "      needs to be done MANUALLY for each router using 'vtysh' OR"
echo "      by adding router-specific 'docker exec ... vtysh -c ...' commands"
echo "      to this script."
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"


# --- Add Host Routes ---
echo ">>> Adding Host Routes..."
# Make sure to use the correct gateway IPs based on your FINAL IP scheme
# Assuming the .3/.4/.5 scheme on 10.0.x.0/24:
HA_CONTAINER="pa3-ha-1" # Verify name with 'sudo docker ps'
HB_CONTAINER="pa3-hb-1" # Verify name with 'sudo docker ps'
R1_GW_FOR_HA="10.0.1.4"  # R1's IP on HA's network
R3_GW_FOR_HB="10.0.6.4"  # R3's IP on HB's network
HA_SUBNET="10.0.1.0/24"
HB_SUBNET="10.0.6.0/24"

sudo docker exec -it "$HA_CONTAINER" route add -net "$HB_SUBNET" gw "$R1_GW_FOR_HA"
sudo docker exec -it "$HB_CONTAINER" route add -net "$HA_SUBNET" gw "$R3_GW_FOR_HB"
echo "--- Done adding host routes ---"


echo ">>> Script finished."
