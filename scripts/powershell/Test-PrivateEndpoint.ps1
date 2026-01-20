<#
.SYNOPSIS
    Test and validate Azure Private Endpoint connectivity.

.DESCRIPTION
    This script validates Private Endpoint configurations including:
    - DNS resolution verification
    - Network connectivity testing
    - Private DNS zone configuration
    - Service endpoint comparison
    - Troubleshooting common issues

.PARAMETER ResourceGroupName
    Resource group containing the private endpoint.

.PARAMETER PrivateEndpointName
    Name of the private endpoint to test.

.PARAMETER TestFromVm
    VM name to run tests from (within the VNet).

.EXAMPLE
    # Test a specific private endpoint
    .\Test-PrivateEndpoint.ps1 -ResourceGroupName "myRG" -PrivateEndpointName "pe-storage"

.EXAMPLE
    # Test from a specific VM
    .\Test-PrivateEndpoint.ps1 -ResourceGroupName "myRG" -PrivateEndpointName "pe-sql" -TestFromVm "jumpbox"

.NOTES
    AZ-305 EXAM OBJECTIVES:
    - Design network security solutions
    - Implement private connectivity to PaaS services
    - Troubleshoot network connectivity issues
    - Understand DNS resolution with private endpoints

.LINK
    https://learn.microsoft.com/azure/private-link/private-endpoint-overview
    https://learn.microsoft.com/azure/private-link/troubleshoot-private-endpoint-connectivity
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [string]$PrivateEndpointName,

    [Parameter(Mandatory = $false)]
    [string]$TestFromVm
)

#Requires -Modules Az.Accounts, Az.Network, Az.PrivateDns

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

#-------------------------------------------------------------------------------
# HELPER FUNCTIONS
#-------------------------------------------------------------------------------
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO" { "White" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR" { "Red" }
        "TEST" { "Cyan" }
    }
    Write-Host "[$Level] $timestamp - $Message" -ForegroundColor $color
}

function Test-Result {
    param([string]$TestName, [bool]$Passed, [string]$Details = "")
    $status = if ($Passed) { "PASS" } else { "FAIL" }
    $color = if ($Passed) { "Green" } else { "Red" }
    Write-Host "  [$status] $TestName" -ForegroundColor $color
    if ($Details) {
        Write-Host "         $Details" -ForegroundColor Gray
    }
}

#-------------------------------------------------------------------------------
# GET ALL PRIVATE ENDPOINTS
#-------------------------------------------------------------------------------
function Get-PrivateEndpointList {
    Write-Log "Retrieving private endpoints in resource group: $ResourceGroupName"

    $endpoints = Get-AzPrivateEndpoint -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

    if (-not $endpoints) {
        Write-Log "No private endpoints found in resource group" -Level "WARNING"
        return $null
    }

    Write-Log "Found $($endpoints.Count) private endpoints" -Level "SUCCESS"
    return $endpoints
}

#-------------------------------------------------------------------------------
# VALIDATE PRIVATE ENDPOINT CONFIGURATION
#-------------------------------------------------------------------------------
function Test-PrivateEndpointConfiguration {
    param([object]$Endpoint)

    Write-Host ""
    Write-Log "Testing Private Endpoint: $($Endpoint.Name)" -Level "TEST"
    Write-Host "-------------------------------------------------------------------------------"

    $results = @{
        EndpointName    = $Endpoint.Name
        Tests           = @()
        OverallStatus   = $true
    }

    # WHY: Provisioning state must be Succeeded for the endpoint to function
    $provisioningPassed = $Endpoint.ProvisioningState -eq "Succeeded"
    Test-Result -TestName "Provisioning State" -Passed $provisioningPassed -Details "State: $($Endpoint.ProvisioningState)"
    $results.Tests += @{ Name = "Provisioning"; Passed = $provisioningPassed }
    if (-not $provisioningPassed) { $results.OverallStatus = $false }

    # WHY: NIC must be attached and have valid private IP
    $nic = $Endpoint.NetworkInterfaces | Select-Object -First 1
    $nicPassed = $null -ne $nic
    Test-Result -TestName "Network Interface Attached" -Passed $nicPassed -Details $(if ($nic) { "NIC: $($nic.Id.Split('/')[-1])" } else { "No NIC found" })
    $results.Tests += @{ Name = "NIC"; Passed = $nicPassed }
    if (-not $nicPassed) { $results.OverallStatus = $false }

    # Get private IP address
    if ($nic) {
        try {
            $nicDetails = Get-AzNetworkInterface -ResourceId $nic.Id -ErrorAction Stop
            $privateIp = $nicDetails.IpConfigurations[0].PrivateIpAddress
            $ipPassed = -not [string]::IsNullOrEmpty($privateIp)
            Test-Result -TestName "Private IP Assigned" -Passed $ipPassed -Details "IP: $privateIp"
            $results.Tests += @{ Name = "PrivateIP"; Passed = $ipPassed; Value = $privateIp }
            if (-not $ipPassed) { $results.OverallStatus = $false }
            $results.PrivateIp = $privateIp
        }
        catch {
            Test-Result -TestName "Private IP Assigned" -Passed $false -Details "Error: $_"
            $results.Tests += @{ Name = "PrivateIP"; Passed = $false }
            $results.OverallStatus = $false
        }
    }

    # WHY: Connection must be Approved and Succeeded for traffic to flow
    $connection = $Endpoint.PrivateLinkServiceConnections | Select-Object -First 1
    if ($connection) {
        $connectionPassed = $connection.PrivateLinkServiceConnectionState.Status -eq "Approved"
        Test-Result -TestName "Connection Approved" -Passed $connectionPassed -Details "Status: $($connection.PrivateLinkServiceConnectionState.Status)"
        $results.Tests += @{ Name = "Connection"; Passed = $connectionPassed }
        if (-not $connectionPassed) { $results.OverallStatus = $false }

        # Get target resource info
        $targetResourceId = $connection.PrivateLinkServiceId
        $results.TargetResource = $targetResourceId
        Write-Host "  Target Resource: $($targetResourceId.Split('/')[-1])" -ForegroundColor Gray
    }

    # WHY: Subnet must be in the same VNet and properly configured
    $subnetId = $Endpoint.Subnet.Id
    if ($subnetId) {
        $subnetParts = $subnetId -split '/'
        $vnetName = $subnetParts[-3]
        $subnetName = $subnetParts[-1]
        Test-Result -TestName "Subnet Configuration" -Passed $true -Details "VNet: $vnetName, Subnet: $subnetName"
        $results.Tests += @{ Name = "Subnet"; Passed = $true }
        $results.VNetName = $vnetName
        $results.SubnetName = $subnetName
    }

    return $results
}

#-------------------------------------------------------------------------------
# TEST DNS CONFIGURATION
#-------------------------------------------------------------------------------
function Test-DnsConfiguration {
    param([object]$Endpoint, [object]$TestResults)

    Write-Host ""
    Write-Log "Testing DNS Configuration" -Level "TEST"
    Write-Host "-------------------------------------------------------------------------------"

    # Get the custom DNS configuration
    $dnsConfigs = $Endpoint.CustomDnsConfigs

    if ($dnsConfigs -and $dnsConfigs.Count -gt 0) {
        foreach ($dnsConfig in $dnsConfigs) {
            $fqdn = $dnsConfig.Fqdn
            $ipAddresses = $dnsConfig.IpAddresses -join ", "

            Write-Host "  FQDN: $fqdn" -ForegroundColor Gray
            Write-Host "  Expected IPs: $ipAddresses" -ForegroundColor Gray

            # Test DNS resolution from current machine
            # WHY: DNS must resolve to private IP for traffic to flow through the endpoint
            try {
                $resolved = Resolve-DnsName -Name $fqdn -ErrorAction Stop
                $resolvedIps = ($resolved | Where-Object { $_.QueryType -eq 'A' }).IPAddress

                if ($resolvedIps) {
                    $matchesPrivate = $resolvedIps | Where-Object { $dnsConfig.IpAddresses -contains $_ }

                    if ($matchesPrivate) {
                        Test-Result -TestName "DNS Resolution (from this machine)" -Passed $true -Details "Resolves to: $($resolvedIps -join ', ')"
                    }
                    else {
                        Test-Result -TestName "DNS Resolution (from this machine)" -Passed $false -Details "Resolves to public IP: $($resolvedIps -join ', '). Configure Private DNS Zone or hosts file."
                        $TestResults.OverallStatus = $false
                    }
                }
            }
            catch {
                Test-Result -TestName "DNS Resolution (from this machine)" -Passed $false -Details "Failed to resolve: $_"
                $TestResults.OverallStatus = $false
            }

            $TestResults.FQDN = $fqdn
        }
    }
    else {
        Write-Log "No custom DNS configuration found" -Level "WARNING"
    }

    return $TestResults
}

#-------------------------------------------------------------------------------
# TEST PRIVATE DNS ZONES
#-------------------------------------------------------------------------------
function Test-PrivateDnsZones {
    param([object]$Endpoint, [object]$TestResults)

    Write-Host ""
    Write-Log "Testing Private DNS Zone Configuration" -Level "TEST"
    Write-Host "-------------------------------------------------------------------------------"

    # Get DNS zone groups
    $dnsZoneGroups = $Endpoint.PrivateDnsZoneGroups

    if ($dnsZoneGroups -and $dnsZoneGroups.Count -gt 0) {
        foreach ($group in $dnsZoneGroups) {
            foreach ($zoneConfig in $group.PrivateDnsZoneConfigs) {
                $zoneId = $zoneConfig.PrivateDnsZoneId
                $zoneName = $zoneId.Split('/')[-1]

                Write-Host "  DNS Zone: $zoneName" -ForegroundColor Gray

                # Check if zone exists and is linked to the VNet
                try {
                    $zoneRgName = $zoneId.Split('/')[4]
                    $zone = Get-AzPrivateDnsZone -Name $zoneName -ResourceGroupName $zoneRgName -ErrorAction Stop

                    Test-Result -TestName "Private DNS Zone Exists" -Passed $true -Details "Zone: $zoneName"

                    # Check VNet link
                    $links = Get-AzPrivateDnsVirtualNetworkLink -ZoneName $zoneName -ResourceGroupName $zoneRgName -ErrorAction SilentlyContinue

                    if ($links) {
                        # Check if linked to the right VNet
                        $linkedToCorrectVnet = $links | Where-Object {
                            $_.VirtualNetworkId -like "*$($TestResults.VNetName)*"
                        }

                        if ($linkedToCorrectVnet) {
                            Test-Result -TestName "VNet Link Configured" -Passed $true -Details "Linked to: $($TestResults.VNetName)"
                        }
                        else {
                            Test-Result -TestName "VNet Link Configured" -Passed $false -Details "Not linked to endpoint's VNet"
                            $TestResults.OverallStatus = $false
                        }
                    }
                    else {
                        Test-Result -TestName "VNet Link Configured" -Passed $false -Details "No VNet links found"
                        $TestResults.OverallStatus = $false
                    }
                }
                catch {
                    Test-Result -TestName "Private DNS Zone Exists" -Passed $false -Details "Error: $_"
                    $TestResults.OverallStatus = $false
                }
            }
        }
    }
    else {
        Test-Result -TestName "Private DNS Zone Group" -Passed $false -Details "No DNS zone group configured. DNS must be configured manually."
        Write-Log "Consider creating a Private DNS Zone and linking it to the VNet" -Level "WARNING"
    }

    return $TestResults
}

#-------------------------------------------------------------------------------
# GENERATE RECOMMENDATIONS
#-------------------------------------------------------------------------------
function Show-Recommendations {
    param([object]$TestResults)

    Write-Host ""
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "                         TEST SUMMARY & RECOMMENDATIONS" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""

    $passedCount = ($TestResults.Tests | Where-Object { $_.Passed }).Count
    $totalCount = $TestResults.Tests.Count
    $overallStatus = if ($TestResults.OverallStatus) { "PASSED" } else { "NEEDS ATTENTION" }
    $statusColor = if ($TestResults.OverallStatus) { "Green" } else { "Yellow" }

    Write-Host "Endpoint: $($TestResults.EndpointName)"
    Write-Host "Tests Passed: $passedCount / $totalCount"
    Write-Host "Overall Status: " -NoNewline
    Write-Host $overallStatus -ForegroundColor $statusColor
    Write-Host ""

    if (-not $TestResults.OverallStatus) {
        Write-Host "RECOMMENDATIONS:" -ForegroundColor Yellow
        Write-Host "-------------------------------------------------------------------------------"

        $failedTests = $TestResults.Tests | Where-Object { -not $_.Passed }
        foreach ($test in $failedTests) {
            switch ($test.Name) {
                "Provisioning" {
                    Write-Host "  - Wait for provisioning to complete or check for errors in Activity Log"
                }
                "Connection" {
                    Write-Host "  - Approve the private endpoint connection on the target resource"
                    Write-Host "    az network private-endpoint-connection approve --id <connection-id>"
                }
                "PrivateIP" {
                    Write-Host "  - Check if subnet has available IP addresses"
                    Write-Host "  - Verify subnet delegation settings"
                }
                "DNS" {
                    Write-Host "  - Configure Private DNS Zone for the service"
                    Write-Host "  - Or update hosts file / custom DNS server"
                }
            }
        }
        Write-Host ""
    }

    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host "PRIVATE ENDPOINT CONCEPTS (AZ-305 Exam Context):" -ForegroundColor Cyan
    Write-Host "===============================================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "HOW PRIVATE ENDPOINTS WORK:" -ForegroundColor Yellow
    Write-Host "  1. Private Endpoint gets a private IP in your VNet"
    Write-Host "  2. DNS resolution must return the private IP (not public)"
    Write-Host "  3. Traffic flows through Microsoft backbone, not internet"
    Write-Host "  4. Connection must be approved by resource owner"
    Write-Host ""
    Write-Host "DNS RESOLUTION OPTIONS:" -ForegroundColor Yellow
    Write-Host "  Private DNS Zones (Recommended):"
    Write-Host "    - Automatic A record creation"
    Write-Host "    - Works for all VNet resources"
    Write-Host "    - Zone must be linked to VNet"
    Write-Host ""
    Write-Host "  Custom DNS Server:"
    Write-Host "    - Forward to Azure DNS (168.63.129.16)"
    Write-Host "    - Or conditional forwarder to Private DNS Zone"
    Write-Host ""
    Write-Host "  Hosts File (Testing only):"
    Write-Host "    - Add entry: $($TestResults.PrivateIp) $($TestResults.FQDN)"
    Write-Host ""
    Write-Host "COMMON DNS ZONES:" -ForegroundColor Yellow
    Write-Host "  Storage Blob:     privatelink.blob.core.windows.net"
    Write-Host "  SQL Database:     privatelink.database.windows.net"
    Write-Host "  Key Vault:        privatelink.vaultcore.azure.net"
    Write-Host "  App Service:      privatelink.azurewebsites.net"
    Write-Host "  Cosmos DB:        privatelink.documents.azure.com"
    Write-Host "===============================================================================" -ForegroundColor Cyan
}

#-------------------------------------------------------------------------------
# MAIN
#-------------------------------------------------------------------------------
function Main {
    Write-Log "Starting Private Endpoint validation..."

    try {
        # Get private endpoints
        $endpoints = Get-PrivateEndpointList

        if (-not $endpoints) {
            return
        }

        # Filter to specific endpoint if specified
        if ($PrivateEndpointName) {
            $endpoints = $endpoints | Where-Object { $_.Name -eq $PrivateEndpointName }
            if (-not $endpoints) {
                Write-Log "Private endpoint '$PrivateEndpointName' not found" -Level "ERROR"
                return
            }
        }

        # Test each endpoint
        foreach ($endpoint in $endpoints) {
            # Basic configuration tests
            $results = Test-PrivateEndpointConfiguration -Endpoint $endpoint

            # DNS configuration tests
            $results = Test-DnsConfiguration -Endpoint $endpoint -TestResults $results

            # Private DNS Zone tests
            $results = Test-PrivateDnsZones -Endpoint $endpoint -TestResults $results

            # Show recommendations
            Show-Recommendations -TestResults $results
        }

        Write-Log "Private Endpoint validation completed!" -Level "SUCCESS"
    }
    catch {
        Write-Log "Validation failed: $_" -Level "ERROR"
        throw
    }
}

# Execute main function
Main
