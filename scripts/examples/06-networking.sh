#!/usr/bin/env bash
# ============================================================================
# TITLE:    AZ-305 Domain 4: Network Solutions
# DOMAIN:   Domain 4 - Design Infrastructure Solutions (30-35%)
# DESCRIPTION:
#   Teaching examples covering hub-spoke VNet topology, VPN Gateway, ExpressRoute,
#   Application Gateway with WAF, Azure Front Door, Azure Firewall, Private
#   Endpoints, NSG/ASG patterns, and load balancing decision trees.
#   Code-review examples for AZ-305 classroom use.
# AUTHOR:   Tim Warner
# DATE:     January 2026
# NOTES:    Not intended for direct execution. Illustrates correct syntax and
#           architectural decision-making for AZ-305 exam preparation.
# ============================================================================

set -euo pipefail

SUBSCRIPTION_ID="00000000-0000-0000-0000-000000000000"
RESOURCE_GROUP="az305-rg"
LOCATION="eastus"
PREFIX="az305"

# ============================================================================
# SECTION 1: Hub-Spoke VNet Topology with Peering
# ============================================================================

# EXAM TIP: Hub-spoke is the STANDARD Azure network topology recommended by
# Microsoft. The hub contains shared services (firewall, VPN gateway, DNS).
# Spokes contain workloads and peer to the hub. This is the #1 networking
# pattern tested on AZ-305.

# WHEN TO USE:
#   Hub-spoke         -> Most enterprise deployments (standard recommendation)
#   Virtual WAN       -> 20+ branches, global transit, Microsoft-managed hub
#   Flat (single VNet) -> Small deployments, POCs (not recommended for production)
#   Mesh peering       -> Direct spoke-to-spoke needed (rare, complex)

# --- Create Hub VNet ---
az network vnet create \
    --name "${PREFIX}-vnet-hub" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --address-prefix "10.0.0.0/16" \
    --subnet-name "AzureFirewallSubnet" \
    --subnet-prefix "10.0.1.0/24"
    # EXAM TIP: Azure Firewall requires a subnet named EXACTLY "AzureFirewallSubnet"
    # with a minimum /26 prefix. This is a common exam question.

# Add GatewaySubnet for VPN/ExpressRoute
az network vnet subnet create \
    --name "GatewaySubnet" \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "${PREFIX}-vnet-hub" \
    --address-prefix "10.0.2.0/24"
    # EXAM TIP: GatewaySubnet must be named EXACTLY "GatewaySubnet".
    # Microsoft recommends /27 minimum, /24 for future growth.

# Add subnet for shared services (DNS, AD DS, jump boxes)
az network vnet subnet create \
    --name "SharedServicesSubnet" \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "${PREFIX}-vnet-hub" \
    --address-prefix "10.0.3.0/24"

# --- Create Spoke VNets ---
az network vnet create \
    --name "${PREFIX}-vnet-spoke-web" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --address-prefix "10.1.0.0/16" \
    --subnet-name "WebSubnet" \
    --subnet-prefix "10.1.1.0/24"

az network vnet create \
    --name "${PREFIX}-vnet-spoke-data" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --address-prefix "10.2.0.0/16" \
    --subnet-name "DataSubnet" \
    --subnet-prefix "10.2.1.0/24"

# --- Create VNet Peerings (hub <-> spoke) ---
# EXAM TIP: Peerings are NOT transitive. Spoke-web cannot reach spoke-data through
# the hub unless you enable "Allow Gateway Transit" on the hub and use Azure Firewall
# or an NVA as the next hop. This is a TOP exam concept.

# Hub -> Spoke-Web peering
az network vnet peering create \
    --name "hub-to-spoke-web" \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "${PREFIX}-vnet-hub" \
    --remote-vnet "${PREFIX}-vnet-spoke-web" \
    --allow-vnet-access true \
    --allow-forwarded-traffic true \
    --allow-gateway-transit true   # Hub shares its gateway with spokes

# Spoke-Web -> Hub peering
az network vnet peering create \
    --name "spoke-web-to-hub" \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "${PREFIX}-vnet-spoke-web" \
    --remote-vnet "${PREFIX}-vnet-hub" \
    --allow-vnet-access true \
    --allow-forwarded-traffic true \
    --use-remote-gateways true     # Spoke uses hub's VPN/ER gateway

# Hub -> Spoke-Data peering (repeat pattern)
az network vnet peering create \
    --name "hub-to-spoke-data" \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "${PREFIX}-vnet-hub" \
    --remote-vnet "${PREFIX}-vnet-spoke-data" \
    --allow-vnet-access true \
    --allow-forwarded-traffic true \
    --allow-gateway-transit true

az network vnet peering create \
    --name "spoke-data-to-hub" \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "${PREFIX}-vnet-spoke-data" \
    --remote-vnet "${PREFIX}-vnet-hub" \
    --allow-vnet-access true \
    --allow-forwarded-traffic true \
    --use-remote-gateways true

# ============================================================================
# SECTION 2: VPN Gateway (S2S) and ExpressRoute Comparison
# ============================================================================

# EXAM TIP: VPN vs ExpressRoute is a CRITICAL exam decision:
#
# +------------------+------------------------+-------------------------------+
# | Feature          | VPN Gateway (S2S)      | ExpressRoute                  |
# +------------------+------------------------+-------------------------------+
# | Connection       | Public internet (IPsec)| Private (MPLS via provider)   |
# | Max bandwidth    | 10 Gbps (VpnGw5)      | 100 Gbps (Direct)            |
# | Latency          | Variable (internet)    | Predictable, low             |
# | SLA              | 99.95% (active-active) | 99.95% (standard circuit)    |
# | Cost             | $200-1300/mo (gateway) | $500-25000/mo (circuit+GW)   |
# | Encryption       | Built-in IPsec/IKEv2   | Optional (MACsec for Direct) |
# | Setup time       | Minutes                | Weeks-months (provider)      |
# | Best for         | Small/medium, backup   | Enterprise, hybrid, high BW  |
# +------------------+------------------------+-------------------------------+

# WHEN TO USE:
#   VPN Gateway    -> Budget-conscious, <1 Gbps, quick setup, as ExpressRoute backup
#   ExpressRoute   -> Enterprise hybrid, >1 Gbps, predictable latency, compliance
#   Both           -> ExpressRoute primary + VPN backup (recommended for production)

# Create a VPN Gateway for site-to-site connectivity
az network public-ip create \
    --name "${PREFIX}-vpngw-pip" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku "Standard" \
    --allocation-method "Static" \
    --zone 1 2 3  # Zone-redundant public IP for gateway HA

az network vnet-gateway create \
    --name "${PREFIX}-vpngw" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --vnet "${PREFIX}-vnet-hub" \
    --gateway-type "Vpn" \
    --vpn-type "RouteBased" \
    --sku "VpnGw2AZ" \
    --public-ip-addresses "${PREFIX}-vpngw-pip" \
    --no-wait
    # EXAM TIP: Use "AZ" SKUs (VpnGw2AZ) for zone-redundant gateways.
    # Gateway deployment takes 30-45 minutes. Use --no-wait in scripts.

# Create local network gateway (represents on-premises network)
az network local-gateway create \
    --name "${PREFIX}-onprem-lng" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --gateway-ip-address "203.0.113.1" \
    --local-address-prefixes "192.168.0.0/16" "172.16.0.0/12"

# Create the S2S VPN connection
az network vpn-connection create \
    --name "${PREFIX}-s2s-connection" \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-gateway1 "${PREFIX}-vpngw" \
    --local-gateway2 "${PREFIX}-onprem-lng" \
    --shared-key "REPLACE-WITH-KEYVAULT-SECRET" \
    --connection-protocol "IKEv2" \
    --enable-bgp false

# ============================================================================
# SECTION 3: Application Gateway with WAF v2
# ============================================================================

# EXAM TIP: Application Gateway is a LAYER 7 (HTTP/HTTPS) load balancer with WAF.
# It provides: SSL termination, URL-based routing, cookie-based session affinity,
# multi-site hosting, and Web Application Firewall (WAF) with OWASP rules.

# WHEN TO USE Application Gateway:
#   - Web apps needing WAF protection (OWASP Top 10)
#   - URL path-based routing (/api/* to backend A, /images/* to backend B)
#   - SSL offloading at the load balancer
#   - Single-region HTTP(S) load balancing
# Use Front Door instead for multi-region or global HTTP load balancing.

# Create a public IP for Application Gateway
az network public-ip create \
    --name "${PREFIX}-appgw-pip" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku "Standard" \
    --allocation-method "Static"

# Create Application Gateway subnet (dedicated, no other resources)
az network vnet subnet create \
    --name "AppGatewaySubnet" \
    --resource-group "$RESOURCE_GROUP" \
    --vnet-name "${PREFIX}-vnet-spoke-web" \
    --address-prefix "10.1.2.0/24"

# Create Application Gateway with WAF v2
az network application-gateway create \
    --name "${PREFIX}-appgw" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku "WAF_v2" \
    --capacity 2 \
    --vnet-name "${PREFIX}-vnet-spoke-web" \
    --subnet "AppGatewaySubnet" \
    --public-ip-address "${PREFIX}-appgw-pip" \
    --http-settings-protocol "Https" \
    --http-settings-port 443 \
    --frontend-port 443 \
    --servers "10.1.1.4" "10.1.1.5" \
    --priority 100

# Enable WAF policy with OWASP 3.2 rules
az network application-gateway waf-policy create \
    --name "${PREFIX}-waf-policy" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION"

az network application-gateway waf-policy managed-rule rule-set add \
    --policy-name "${PREFIX}-waf-policy" \
    --resource-group "$RESOURCE_GROUP" \
    --type "OWASP" \
    --version "3.2"

# EXAM TIP: WAF operates in two modes:
#   Detection mode -> Logs violations but does NOT block (use for initial tuning)
#   Prevention mode -> Blocks violations (use after tuning false positives)
# Always start in Detection mode and review logs before switching to Prevention.

az network application-gateway waf-policy policy-setting update \
    --policy-name "${PREFIX}-waf-policy" \
    --resource-group "$RESOURCE_GROUP" \
    --state "Enabled" \
    --mode "Detection"

# ============================================================================
# SECTION 4: Azure Front Door with Custom Domains
# ============================================================================

# EXAM TIP: Azure Front Door is a GLOBAL Layer 7 load balancer + CDN + WAF.
# Key difference from Application Gateway: Front Door is GLOBAL (anycast POP),
# App Gateway is REGIONAL (single region). Front Door operates at the edge.

# WHEN TO USE Front Door vs Application Gateway:
#   Front Door          -> Multi-region apps, global users, CDN + WAF at edge
#   Application Gateway -> Single-region apps, internal VNet load balancing
#   Traffic Manager     -> DNS-based global routing (no inline processing)
#   Load Balancer       -> Layer 4 (TCP/UDP), non-HTTP workloads

az afd profile create \
    --profile-name "${PREFIX}-afd" \
    --resource-group "$RESOURCE_GROUP" \
    --sku "Premium_AzureFrontDoor"
    # EXAM TIP: Premium SKU supports Private Link origins (connect to private backends).
    # Standard SKU supports WAF and CDN but NOT Private Link origins.

# Add an endpoint
az afd endpoint create \
    --endpoint-name "${PREFIX}-endpoint" \
    --profile-name "${PREFIX}-afd" \
    --resource-group "$RESOURCE_GROUP" \
    --enabled-state "Enabled"

# Add an origin group (backend pool)
az afd origin-group create \
    --origin-group-name "webapp-origins" \
    --profile-name "${PREFIX}-afd" \
    --resource-group "$RESOURCE_GROUP" \
    --probe-request-type "HEAD" \
    --probe-protocol "Https" \
    --probe-interval-in-seconds 30 \
    --probe-path "/health" \
    --sample-size 4 \
    --successful-samples-required 3

# Add origins (backend servers in different regions)
az afd origin create \
    --origin-name "eastus-webapp" \
    --origin-group-name "webapp-origins" \
    --profile-name "${PREFIX}-afd" \
    --resource-group "$RESOURCE_GROUP" \
    --host-name "${PREFIX}-webapp-eastus.azurewebsites.net" \
    --origin-host-header "${PREFIX}-webapp-eastus.azurewebsites.net" \
    --http-port 80 \
    --https-port 443 \
    --priority 1 \
    --weight 1000 \
    --enabled-state "Enabled"

az afd origin create \
    --origin-name "westus-webapp" \
    --origin-group-name "webapp-origins" \
    --profile-name "${PREFIX}-afd" \
    --resource-group "$RESOURCE_GROUP" \
    --host-name "${PREFIX}-webapp-westus.azurewebsites.net" \
    --origin-host-header "${PREFIX}-webapp-westus.azurewebsites.net" \
    --http-port 80 \
    --https-port 443 \
    --priority 1 \
    --weight 1000 \
    --enabled-state "Enabled"

# Create a route connecting endpoint to origin group
az afd route create \
    --route-name "default-route" \
    --endpoint-name "${PREFIX}-endpoint" \
    --profile-name "${PREFIX}-afd" \
    --resource-group "$RESOURCE_GROUP" \
    --origin-group "webapp-origins" \
    --supported-protocols "Https" \
    --https-redirect "Enabled" \
    --patterns-to-match "/*" \
    --forwarding-protocol "HttpsOnly"

# ============================================================================
# SECTION 5: Azure Firewall with Policy Rules
# ============================================================================

# EXAM TIP: Azure Firewall is a managed, cloud-native network firewall.
# It provides: L3-L7 filtering, threat intelligence, FQDN filtering, and
# centralized policy management. In hub-spoke, Azure Firewall sits in the HUB
# and inspects all spoke-to-spoke and spoke-to-internet traffic.

# WHEN TO USE Azure Firewall:
#   Azure Firewall   -> Centralized egress control, FQDN filtering, threat intel
#   NSG              -> Basic L4 allow/deny per subnet or NIC (always use alongside)
#   Third-party NVA  -> Existing firewall investment (Palo Alto, Fortinet, Check Point)
#   Azure WAF        -> HTTP/HTTPS inspection only (Layer 7, use WITH firewall)

# Create Azure Firewall public IP
az network public-ip create \
    --name "${PREFIX}-azfw-pip" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku "Standard" \
    --allocation-method "Static"

# Create Azure Firewall Policy (modern approach, replaces classic rules)
az network firewall policy create \
    --name "${PREFIX}-fw-policy" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --sku "Premium" \
    --threat-intel-mode "Deny"  # Block known malicious IPs/domains
    # EXAM TIP: Premium SKU adds TLS inspection, IDPS, URL filtering, web categories.
    # Standard SKU covers basic L4 rules, FQDN filtering, and threat intelligence.

# Create a rule collection group for organizing firewall rules
az network firewall policy rule-collection-group create \
    --name "DefaultRuleCollectionGroup" \
    --policy-name "${PREFIX}-fw-policy" \
    --resource-group "$RESOURCE_GROUP" \
    --priority 200

# Network rule: Allow spoke-to-spoke traffic through the hub firewall
az network firewall policy rule-collection-group collection add-filter-collection \
    --rule-collection-group-name "DefaultRuleCollectionGroup" \
    --policy-name "${PREFIX}-fw-policy" \
    --resource-group "$RESOURCE_GROUP" \
    --name "AllowSpokeToSpoke" \
    --collection-priority 100 \
    --action "Allow" \
    --rule-type "NetworkRule" \
    --rule-name "spoke-web-to-spoke-data" \
    --source-addresses "10.1.0.0/16" \
    --destination-addresses "10.2.0.0/16" \
    --destination-ports "1433" "443" \
    --ip-protocols "TCP"

# Application rule: Allow outbound HTTPS to specific FQDNs
az network firewall policy rule-collection-group collection add-filter-collection \
    --rule-collection-group-name "DefaultRuleCollectionGroup" \
    --policy-name "${PREFIX}-fw-policy" \
    --resource-group "$RESOURCE_GROUP" \
    --name "AllowOutboundHttps" \
    --collection-priority 200 \
    --action "Allow" \
    --rule-type "ApplicationRule" \
    --rule-name "allow-microsoft-updates" \
    --source-addresses "10.0.0.0/8" \
    --protocols "Https=443" \
    --target-fqdns "*.microsoft.com" "*.windowsupdate.com" "*.ubuntu.com"

# Create the Azure Firewall
az network firewall create \
    --name "${PREFIX}-azfw" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --vnet-name "${PREFIX}-vnet-hub" \
    --firewall-policy "${PREFIX}-fw-policy" \
    --sku "AZFW_VNet" \
    --tier "Premium"

# EXAM TIP: Route all spoke traffic through the firewall using UDRs (User-Defined Routes).
# Default route 0.0.0.0/0 -> Azure Firewall private IP forces all internet-bound
# traffic through the firewall for inspection.
FIREWALL_PRIVATE_IP=$(az network firewall show \
    --name "${PREFIX}-azfw" \
    --resource-group "$RESOURCE_GROUP" \
    --query "ipConfigurations[0].privateIPAddress" --output tsv)

az network route-table create \
    --name "${PREFIX}-rt-spoke" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION"

az network route-table route create \
    --name "default-to-firewall" \
    --route-table-name "${PREFIX}-rt-spoke" \
    --resource-group "$RESOURCE_GROUP" \
    --address-prefix "0.0.0.0/0" \
    --next-hop-type "VirtualAppliance" \
    --next-hop-ip-address "$FIREWALL_PRIVATE_IP"

# Associate UDR with spoke subnets
az network vnet subnet update \
    --name "WebSubnet" \
    --vnet-name "${PREFIX}-vnet-spoke-web" \
    --resource-group "$RESOURCE_GROUP" \
    --route-table "${PREFIX}-rt-spoke"

# ============================================================================
# SECTION 6: Private Endpoints and Private Link
# ============================================================================

# EXAM TIP: Private Endpoints bring Azure PaaS services INTO your VNet with a
# private IP address. Traffic stays on the Microsoft backbone -- never traverses
# the public internet. This is the #1 security pattern for PaaS services on AZ-305.

# WHEN TO USE:
#   Private Endpoints -> ANY PaaS service accessed from VNet (SQL, Storage, Key Vault, etc.)
#   Service Endpoints -> Simpler alternative but traffic still uses public IP (less secure)
#   Public access     -> NEVER for production data services (only for truly public content)
# Microsoft recommends Private Endpoints over Service Endpoints for new deployments.

# Create a Private Endpoint for Azure SQL Database
az network private-endpoint create \
    --name "${PREFIX}-pe-sql" \
    --resource-group "$RESOURCE_GROUP" \
    --location "$LOCATION" \
    --vnet-name "${PREFIX}-vnet-spoke-data" \
    --subnet "DataSubnet" \
    --connection-name "${PREFIX}-sql-connection" \
    --private-connection-resource-id "/subscriptions/${SUBSCRIPTION_ID}/resourceGroups/${RESOURCE_GROUP}/providers/Microsoft.Sql/servers/${PREFIX}-sql" \
    --group-ids "sqlServer"

# Create Private DNS zone for automatic name resolution
# EXAM TIP: Private DNS zones are REQUIRED for Private Endpoints to work transparently.
# Without DNS, apps must use the private IP directly (not maintainable).
# Each service has a specific zone name: privatelink.database.windows.net for SQL.
az network private-dns zone create \
    --name "privatelink.database.windows.net" \
    --resource-group "$RESOURCE_GROUP"

# Link DNS zone to the VNet
az network private-dns link vnet create \
    --name "${PREFIX}-sql-dns-link" \
    --resource-group "$RESOURCE_GROUP" \
    --zone-name "privatelink.database.windows.net" \
    --virtual-network "${PREFIX}-vnet-spoke-data" \
    --registration-enabled false

# Create DNS record group for the private endpoint
az network private-endpoint dns-zone-group create \
    --endpoint-name "${PREFIX}-pe-sql" \
    --resource-group "$RESOURCE_GROUP" \
    --name "sqlDnsGroup" \
    --private-dns-zone "privatelink.database.windows.net" \
    --zone-name "sql"

# EXAM TIP: After creating Private Endpoint, DISABLE public access on the PaaS service:
az sql server update \
    --name "${PREFIX}-sql" \
    --resource-group "$RESOURCE_GROUP" \
    --set publicNetworkAccess="Disabled"

# ============================================================================
# SECTION 7: Load Balancing Decision Tree
# ============================================================================

# EXAM TIP: Azure has FOUR load balancing services. The exam frequently asks
# you to choose the right one. Use this decision tree:
#
#   Is the traffic HTTP/HTTPS?
#     |-- YES: Is it global (multi-region)?
#     |    |-- YES -> Azure Front Door (global L7, CDN, WAF)
#     |    |-- NO  -> Application Gateway (regional L7, WAF, URL routing)
#     |-- NO: Is it global (multi-region)?
#          |-- YES -> Traffic Manager (DNS-based, no inline processing)
#          |-- NO  -> Azure Load Balancer (regional L4, TCP/UDP)
#
#   +--------------------+--------+-----------+----------+------------------+
#   | Feature            | Front  | App       | Traffic  | Load             |
#   |                    | Door   | Gateway   | Manager  | Balancer         |
#   +--------------------+--------+-----------+----------+------------------+
#   | Layer              | 7      | 7         | DNS      | 4                |
#   | Scope              | Global | Regional  | Global   | Regional         |
#   | Protocol           | HTTP(S)| HTTP(S)   | Any      | TCP/UDP          |
#   | WAF                | Yes    | Yes       | No       | No               |
#   | SSL offload        | Yes    | Yes       | No       | No               |
#   | URL path routing   | Yes    | Yes       | No       | No               |
#   | Private Link origin| Premium| No        | No       | No               |
#   | Use case           | Global | Internal  | DNS      | Non-HTTP,        |
#   |                    | web    | web apps  | routing  | HA ports, NVAs   |
#   +--------------------+--------+-----------+----------+------------------+

# WHEN TO USE NSG vs ASG vs Azure Firewall:
#   NSG (Network Security Group):
#     - L4 stateful firewall at subnet or NIC level
#     - ALWAYS use as baseline defense on every subnet
#     - Free (included with VNet)
#
#   ASG (Application Security Group):
#     - Logical grouping for NSG rules (avoid IP-based rules)
#     - Group VMs by role: "WebServers", "DbServers", "AppServers"
#     - Makes NSG rules readable and maintainable
#
#   Azure Firewall:
#     - Centralized L4-L7 firewall in the hub
#     - FQDN filtering, threat intelligence, TLS inspection (Premium)
#     - Use for east-west (spoke-to-spoke) and north-south (internet) control

# ============================================================================
# SECTION 8: Network Watcher Diagnostics
# ============================================================================

# EXAM TIP: Network Watcher is the diagnostic toolkit for Azure networking.
# Key capabilities: IP flow verify, next hop, connection troubleshoot,
# NSG diagnostics, packet capture, VPN troubleshoot, topology view.

# WHEN TO USE each diagnostic tool:
#   IP Flow Verify      -> "Is traffic being blocked?" (tests NSG rules)
#   Next Hop            -> "Where is traffic going?" (routing path)
#   Connection Troubleshoot -> "Can VM A reach VM B?" (end-to-end connectivity)
#   NSG Diagnostics     -> "Which NSG rule is matching?" (detailed rule evaluation)
#   Packet Capture      -> Deep inspection of actual network packets

# IP Flow Verify: Check if traffic from VM to SQL is allowed
az network watcher test-ip-flow \
    --direction "Outbound" \
    --protocol "TCP" \
    --local "10.1.1.4:*" \
    --remote "10.2.1.4:1433" \
    --vm "${PREFIX}-vm-web" \
    --resource-group "$RESOURCE_GROUP"

# Connection Troubleshoot: End-to-end connectivity test
az network watcher test-connectivity \
    --source-resource "${PREFIX}-vm-web" \
    --dest-resource "${PREFIX}-vm-data" \
    --dest-port 1433 \
    --resource-group "$RESOURCE_GROUP"

# Next Hop: Determine routing path
az network watcher show-next-hop \
    --vm "${PREFIX}-vm-web" \
    --resource-group "$RESOURCE_GROUP" \
    --source-ip "10.1.1.4" \
    --dest-ip "10.2.1.4"

echo "Networking configuration examples complete."
echo "Hub VNet: ${PREFIX}-vnet-hub (10.0.0.0/16)"
echo "Spoke Web: ${PREFIX}-vnet-spoke-web (10.1.0.0/16)"
echo "Spoke Data: ${PREFIX}-vnet-spoke-data (10.2.0.0/16)"
