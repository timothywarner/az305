# AZ-305 Design Course - Tim Warner

## Schedule (Central Time)
- 9:00 AM - Start Segment 1
- 9:50 AM - 10-minute break
- 10:00 AM - Start Segment 2
- 10:50 AM - 10-minute break
- 11:00 AM - Start Segment 3
- 11:50 AM - 10-minute break
- 12:00 PM - Start Segment 4
- 12:50 PM - 10-minute break
- 1:00 PM - Start Segment 5
- 1:50 PM - Course Completion

## Segment 1 (9:00-9:50) - Identity, Governance & Monitoring
**Theme: "Identity is the New Security Perimeter"**
- Design logging and monitoring solutions
  - Log Analytics workspace design
  - Log routing and retention
  - Monitoring solution architecture
- Design authentication and authorization
  - Entra ID B2B/B2C architecture
  - RBAC and custom roles
  - Managed Identities vs Service Principals
- Design governance solutions
  - Management group hierarchy
  - Resource tagging strategy
  - Policy as Code implementation

**Live Demo Flow:**
1. Log Analytics workspace setup
2. Entra ID tenant configuration
3. Custom RBAC role creation
4. Policy initiative deployment

## Segment 2 (10:00-10:50) - Data Storage Solutions
**Theme: "Right Data, Right Place"**
- Design relational data solutions
  - SQL service tiers and compute
  - Database scalability patterns
  - Data protection strategies
- Design semi-structured/unstructured solutions
  - Cosmos DB partition design
  - Storage account performance tiers
  - Data Lake architecture
- Design data integration
  - Data Factory patterns
  - Synapse Analytics setup
  - Data mesh architecture

**Live Demo Flow:**
1. SQL DB elastic pools
2. Cosmos DB multi-region
3. Storage account lifecycle
4. Data Factory pipeline

## Segment 3 (11:00-11:50) - Business Continuity
**Theme: "Always Available, Always Compliant"**
- Design backup and disaster recovery
  - Azure Backup vault architecture
  - Cross-region recovery
  - Hybrid workload protection
- Design high availability solutions
  - Compute HA patterns
  - Database HA architecture
  - Storage redundancy options

**Live Demo Flow:**
1. Backup vault configuration
2. Cross-region replication
3. Availability Zones setup
4. Traffic Manager profiles

## Segment 4 (12:00-12:50) - Infrastructure Solutions
**Theme: "Modern App Architecture Patterns"**
- Design compute solutions
  - VM-based architecture
  - Container Apps vs AKS
  - Serverless patterns
- Design application architecture
  - Event-driven patterns
  - API Management
  - Caching strategies
- Design migrations
  - Cloud Adoption Framework
  - Migration assessment
  - Workload migration patterns

**Live Demo Flow:**
1. Container Apps with Dapr
2. Event Grid custom topics
3. APIM with OAuth2
4. Migration assessment

## Segment 5 (1:00-1:50) - Network Solutions
**Theme: "Zero Trust Networking"**
- Design connectivity solutions
  - Hub-spoke vs Virtual WAN
  - Private Link vs Service Endpoints
  - Internet connectivity patterns
- Design network optimization
  - Load balancing solutions
  - Network security patterns
  - Performance optimization

**Live Demo Flow:**
1. Hub-spoke with Azure CLI
2. Private Link service setup
3. Application Gateway WAF
4. Network performance monitoring

## Key Focus Areas
- Every demo uses managed identity
- All resources are Private Link enabled
- Zero Trust architecture throughout
- Cost optimization at every step

## Required Tools
- VS Code with Azure Tools
- Azure CLI/PowerShell 7
- Bicep/ARM templates
- Azure Portal for validation
