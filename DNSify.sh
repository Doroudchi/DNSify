#!/bin/bash

# Function to read DNS servers from the ServerList file
load_dns_servers_from_file() {
    local file_path="./ServerList"
    
    if [[ ! -f "$file_path" ]]; then
        echo "Server list file not found at: $file_path"
        exit 1
    fi

    # Read the file into an array, skipping empty lines
    mapfile -t dns_servers < <(grep -E "^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$" "$file_path")
    
    if [[ ${#dns_servers[@]} -eq 0 ]]; then
        echo "Server list file is empty or contains no valid IP addresses."
        exit 1
    fi
}

# Save original DNS settings
original_dns=$(grep nameserver /etc/resolv.conf | awk '{print $2}')

# Function to test a DNS server
test_dns() {
    local dns=$1
    echo "nameserver $dns" | sudo tee /etc/resolv.conf > /dev/null
    response=$(curl -s -o /dev/null -w "%{http_code}" "https://www.spotify.com")
    if [[ $response -ge 400 ]]; then
        echo "HTTP request failed. Spotify might be unreachable. Status Code: $response"
        return 1
    else
        echo "SPOTIFY IS CONNECTED with Status Code: $response"
        return 0
    fi
}

# Function to reset DNS to original settings
cleanup() {
    echo "Resetting DNS to default..."
    echo "nameserver $original_dns" | sudo tee /etc/resolv.conf > /dev/null
    echo "DNS reset to default."
}

# Trap the script exit to always reset DNS
trap cleanup EXIT

# Load DNS servers from the ServerList file
load_dns_servers_from_file

# Flag to track whether a working DNS has been found
dns_found=false

# Iterate through the DNS servers and test each one
for dns in "${dns_servers[@]}"; do
    echo "Checking DNS: $dns"
    if test_dns "$dns"; then
        echo "$dns works! Setting as your DNS."
        dns_found=true
        break
    else
        echo "$dns failed."
    fi
done

# If no working DNS is found, exit the script
if ! $dns_found; then
    echo "No working DNS found. Exiting the script."
    exit 1
fi

# Keep the script running
echo "Press Ctrl+C or close the terminal to stop the script and reset DNS to default."
while true; do
    sleep 10 
done
