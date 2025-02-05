# ExpressRoute vs VPN Gateway: Azure Connectivity Comparison

## Quick Feature Matrix

| Feature | ExpressRoute | VPN Gateway |
|---------|--------------|-------------|
| Connection Type | Private dedicated | Public internet |
| Bandwidth | Up to 100 Gbps | Up to 10 Gbps |
| SLA | 99.95% | 99.9% |
| Routing | BGP required | Static/BGP |
| Initial Setup Time | Weeks/Months | Hours/Days |
| Cost | Higher | Lower |
| Security | Private connection | IPsec encryption |

## ExpressRoute Deep Dive

### Key Characteristics
- Private dedicated connection
- Layer 3 connectivity
- No transit over public internet
- Multiple peering options

### Circuit SKUs
- **Standard**: Up to 10 Gbps
- **Premium**: 
  - Up to 100 Gbps
  - Global connectivity
  - More BGP routes
  - More VNet links

### Peering Types
1. **Private Peering**
   - VNet access
   - Direct connection to VNets
   
2. **Microsoft Peering**
   - Microsoft 365
   - Azure PaaS services
   
3. **Public Peering (Legacy)**
   - Deprecated

### High Availability Options
- **Zone-redundant Gateways**
  - Cross-zone resilience
  - Higher availability

- **Circuit Redundancy**
  - Active/Active circuits
  - Different metro locations

## VPN Gateway Deep Dive

### Types
1. **Route-based**
   - Most common
   - Dynamic routing (BGP)
   - Point-to-site support
   
2. **Policy-based**
   - Legacy support
   - Static routing only
   - Single S2S tunnel

### SKUs and Features
- **Basic**: Dev/test only
- **VpnGw1/2/3**: Production
- **VpnGw4/5**: Highest performance
- **Zone-redundant**: AZ support

### Connection Types
1. **Site-to-Site (S2S)**
   - Branch offices
   - On-premises datacenters
   
2. **Point-to-Site (P2S)**
   - Remote users
   - SSTP/IKEv2/OpenVPN

### Active/Active vs Active/Passive
- **Active/Active**
  - Two instances
  - Better failover
  - Higher throughput
  
- **Active/Passive**
  - Automatic failover
  - Standard setup

## Decision Framework

### Choose ExpressRoute When:
1. **Performance Requirements**
   - Need guaranteed bandwidth
   - Low latency critical
   - Large data transfers

2. **Security Requirements**
   - No public internet transit
   - Strict compliance needs
   - Predictable performance

3. **Scenarios**
   - Enterprise workloads
   - Mission-critical apps
   - Cloud migration projects

### Choose VPN Gateway When:
1. **Business Needs**
   - Small/medium workloads
   - Dev/test environments
   - Backup/DR scenarios

2. **Budget Constraints**
   - Lower initial cost
   - Flexible scaling
   - Quick deployment needed

3. **Connectivity Type**
   - Remote user access
   - Small branch offices
   - Temporary connections

## Common Exam Scenarios

### Scenario 1: Enterprise Migration