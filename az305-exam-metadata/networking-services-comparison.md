# Azure Networking Services Comparison Guide

## Key Services Overview

### Traffic Manager
- **Type**: Global DNS-based traffic routing
- **Key Features**:
  - Multiple routing methods (Priority, Weighted, Performance, Geographic)
  - Endpoint monitoring and failover
  - DNS-based load balancing
- **Use Cases**:
  - Global load balancing
  - Failover scenarios
  - Blue-green deployments
  - A/B testing

### Application Gateway
- **Type**: Layer 7 (HTTP/HTTPS) load balancer
- **Key Features**:
  - Web Application Firewall (WAF)
  - SSL/TLS termination
  - URL-based routing
  - Cookie-based session affinity
- **Use Cases**:
  - Web farms
  - Multi-site hosting
  - SSL offloading
  - Security (WAF)

### Azure Front Door
- **Type**: Global, unified edge service
- **Features Comparison**:

#### Traffic Manager-like Features
- Global load balancing
- DNS routing
- Health probes
- **Advantages over Traffic Manager**:
  - Anycast protocol (faster than DNS)
  - Real-time session affinity

#### Application Gateway-like Features
- Layer 7 routing
- SSL termination
- URL-based routing
- **Differences from App Gateway**:
  - Global rather than regional
  - Basic WAF (not full capability)

#### CDN-like Features
- Content caching
- Dynamic compression
- Integrated with edge network

#### Security Features
- Basic WAF capabilities
- DDoS protection
- Bot protection

## When to Use Each Service

### Use Front Door When
- You need a unified global HTTP/HTTPS routing solution
- You want integrated edge security
- Performance is critical (Anycast benefits)
- You prefer simplified management
- Native Azure integration is important

### Use Individual Services When

#### Application Gateway
- Full WAF capabilities are required
- Regional deployment is preferred
- Detailed control over WAF rules is needed

#### Traffic Manager
- Pure DNS-based routing is sufficient
- Non-HTTP protocols are being used
- Simple global routing is needed

#### Azure CDN
- Advanced CDN features are required
- Specific CDN providers are needed

#### Azure Firewall
- Full L3-L7 firewall capabilities are required
- Network-level security is the primary concern

## Exam Tips
- Focus on understanding service combinations for different scenarios
- Know the key differentiators between services
- Understand global vs regional implications
- Be prepared for questions about cost optimization and performance
- Study hybrid scenarios where multiple services work together

## Additional Resources
- [Azure Front Door Documentation](https://learn.microsoft.com/en-us/azure/frontdoor/front-door-overview)
- [Application Gateway Documentation](https://learn.microsoft.com/en-us/azure/application-gateway/overview)
- [Traffic Manager Documentation](https://learn.microsoft.com/en-us/azure/traffic-manager/traffic-manager-overview)

---
*This guide is part of the AZ-305 exam preparation materials.* 