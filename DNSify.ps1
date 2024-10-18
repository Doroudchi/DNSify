# Function to retrieve the list of DNS servers from the ServerList file
function Get-DnsServersFromFile {
    $filePath = Join-Path -Path (Get-Location) -ChildPath "ServerList"
    
    if (-Not (Test-Path $filePath)) {
        Write-Error "Server list file not found at: $filePath"
        exit
    }
    
    try {
        # Read all lines from the file into an array of DNS server IPs
        $dnsServers = Get-Content -Path $filePath | Where-Object { $_ -match "^\d{1,3}(\.\d{1,3}){3}$" }  # Basic validation for IP addresses
        if ($dnsServers.Count -eq 0) {
            Write-Error "Server list file is empty or contains no valid IP addresses."
            exit
        }
        return $dnsServers
    } catch {
        Write-Error "Error reading server list file: $_"
        exit
    }
}

# Function to retrieve the first active network adapter
function Get-ActiveNetworkAdapter {
    $adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
    if ($null -eq $adapter) {
        Write-Error "No active network adapter found!"
        exit
    }
    return $adapter
}

# Function to test DNS by making a request to a given URL
function Test-DNS {
    param(
        [string]$dns, 
        [string]$testUrl = "https://www.spotify.com"  # Allowing URL to be passed for flexibility
    )
    
    # Set the DNS server for the active network adapter
    Set-DnsClientServerAddress -InterfaceAlias $adapterName -ServerAddresses $dns
    
    # Test the connection to the provided URL
    try {
        $response = & curl.exe -s -o NUL -w "%{http_code}" $testUrl
        if ($response -ge 400) {
            Write-Warning "HTTP request failed. Status Code: $response"
            return $false
        } else {
            Write-Host "Connection successful to $testUrl with DNS $dns. Status Code: $response"
            return $true
        }
    } catch {
        Write-Error "Error during HTTP request: $_"
        return $false
    }
}

# Function to reset DNS back to default after execution
function Reset-DNS {
    param([string[]]$originalDNS)
    Write-Host "Resetting DNS to default..." -ForegroundColor Yellow
    Set-DnsClientServerAddress -InterfaceAlias $adapterName -ServerAddresses $originalDNS
    Write-Host "DNS reset to default."
}

# Main script logic
function Main {
    # Load DNS servers from file
    $dnsServers = Get-DnsServersFromFile
    Write-Host "Loaded DNS servers from file: $dnsServers"

    # Get the active network adapter
    $activeAdapter = Get-ActiveNetworkAdapter
    $adapterName = $activeAdapter.Name
    Write-Host "Detected active network adapter: $adapterName"

    # Save the current DNS settings
    $originalDNS = Get-DnsClientServerAddress -InterfaceAlias $adapterName | Select-Object -ExpandProperty ServerAddresses
    
    # Initialize a flag to track whether a working DNS was found
    $dnsFound = $false
    
    # Iterate through the DNS servers and test each one
    foreach ($dns in $dnsServers) {
        Write-Host "Testing DNS: $dns..."
        if (Test-DNS -dns $dns) {
            Write-Host "$dns is functional! Setting it as the active DNS."
            Set-DnsClientServerAddress -InterfaceAlias $adapterName -ServerAddresses $dns
            $dnsFound = $true
            break
        } else {
            Write-Warning "$dns failed."
        }
    }

    # If no working DNS is found, exit the script
    if (-not $dnsFound) {
        Write-Error "No working DNS found. Exiting script."
        exit
    }
    
    # Keep the script running and allow for manual interruption
    Write-Host "Press Ctrl+C to stop the script and reset DNS to default."
    try {
        while ($true) {
            Start-Sleep -Seconds 10
        }
    } finally {
        # Always reset DNS to the original value
        Reset-DNS -originalDNS $originalDNS
    }
}

# Execute the main function
Main
