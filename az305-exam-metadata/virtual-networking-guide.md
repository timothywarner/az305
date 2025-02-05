# Azure Virtual Networking for Solutions Architects

## 🎯 Exam-Relevant Focus Areas

### Virtual Network Core Concepts
- **VNet Basics**
  - Address space planning (use RFC 1918)
  - Subnets and subnet delegation
  - Region and subscription boundaries
  - Resource group considerations

### Connectivity Solutions

#### Internet Connectivity
- **Public IP Addresses**
  - Standard vs Basic SKU
  - Static vs Dynamic
  - IPv4 and IPv6 considerations

- **Internet-Facing Load Balancers**
  - When to use Public Load Balancer
  - When to use Application Gateway
  - NAT considerations

#### On-Premises Connectivity
- **VPN Solutions**
  - Point-to-Site (P2S)
    - Supported protocols (OpenVPN, IKEv2)
    - Certificate authentication
  - Site-to-Site (S2S)
    - Active/Passive vs Active/Active
    - BGP support
    
- **ExpressRoute**
  - Circuit SKUs and features
  - Peering options (Private, Microsoft, Public)
  - FastPath (Ultra Performance)
  - Global Reach
  
- **Virtual WAN**
  - Hub and Spoke at scale
  - Branch connectivity
  - Inter-hub networking

### Network Performance Optimization
- **Network Virtual Appliances (NVAs)**
  - Routing considerations
  - High availability patterns
  
- **Azure Load Balancer**
  - Internal vs Public
  - Standard vs Basic SKU
  - Load balancing algorithms
  
- **ExpressRoute FastPath**
  - Bypass hub for better performance
  - Use cases and limitations

### Network Security
- **Network Security Groups (NSGs)**
  - Subnet and NIC association
  - Rule processing order
  - Service Tags
  - Application Security Groups

- **Azure Firewall**
  - DNAT rules
  - Network rules
  - Application rules
  - Threat Intelligence

- **Private Link & Private Endpoints**
  - Service connection security
  - DNS considerations
  - Cross-region access

### Hybrid Patterns
- **Hub and Spoke**
  - Central services hub
  - Shared services
  - Transit routing

- **Virtual WAN Hub**
  - When to choose over traditional hub-spoke
  - Routing and security

## 🎯 Key Design Considerations

### High Availability
- Use Availability Zones
- Implement redundant connectivity
- Consider regional pairing
- Deploy redundant NVAs

### Security
- Zero Trust approach
- Network segmentation
- Proper subnet design
- Security service chaining

### Performance
- Choose appropriate SKUs
- Optimize routing
- Use appropriate peering options
- Consider bandwidth requirements

## 📝 Exam Tips

### Common Scenario Types
1. **Hybrid Connectivity**
   - Choose between ExpressRoute, VPN, and Virtual WAN
   - Determine appropriate SKUs and redundancy

2. **Security Requirements**
   - Implement proper network isolation
   - Choose between NSGs, Azure Firewall, and NVAs
   - Design Private Link solutions

3. **Performance Optimization**
   - Select appropriate load balancing solutions
   - Optimize routing paths
   - Choose correct SKUs

### Remember
- Always consider cost implications
- Focus on enterprise-scale solutions
- Prioritize security and compliance
- Consider operational overhead

## 🔍 Design Decision Framework

When designing network solutions, consider:

1. **Connectivity Requirements**
   - Bandwidth needs
   - Latency requirements
   - Geographic distribution
   - Reliability requirements

2. **Security Requirements**
   - Regulatory compliance
   - Data sovereignty
   - Traffic inspection needs
   - Isolation requirements

3. **Operational Requirements**
   - Monitoring needs
   - Management overhead
   - Team expertise
   - Budget constraints

## Best Practices

### Private Endpoint
- Plan DNS strategy early
- Consider hub-spoke implications
- Account for additional costs
- Plan IP addressing carefully

### Service Endpoint
- Use with NSGs for added security
- Enable on specific subnets only
- Consider regional limitations
- Monitor service policies

## Exam Tips
- Understand cost implications
- Know DNS requirements
- Remember network flow differences
- Focus on security implications
- Consider hybrid scenarios

---
*This guide is specifically focused on AZ-305 exam objectives regarding Azure networking security and connectivity patterns.* 