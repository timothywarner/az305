# AZ-305 Crash Course - Tim Warner's Way

## Schedule (Central Time)
- 11:00 AM - Start Segment 1
- 12:00 PM - 9-minute break
- 12:09 PM - Start Segment 2
- 01:00 PM - 9-minute break
- 01:09 PM - Start Segment 3
- 02:00 PM - 9-minute break
- 02:09 PM - Start Segment 4
- 03:00 PM - 9-minute break
- 03:09 PM - Start Segment 5
- 04:00 PM - Course Completion

## Hour 1 (11:00-12:00) - Identity & Security: Your Foundation
**Theme: "Identity is the New Security Perimeter"**
- Entra ID B2B/B2C architecture decisions
- RBAC done right (no more Owner role!)
- Key Vault secrets management
- Managed Identities vs Service Principals

**Live Demo Flow:**
1. Entra ID tenant configuration
2. Custom RBAC role creation
3. Key Vault with Private Link
4. System-assigned vs User-assigned MI

## Hour 2 (12:09-1:00) - Data Platform Decisions
**Theme: "Right Data, Right Place"**
- SQL vs NoSQL decision framework
- Cosmos DB partition design
- Storage account performance tiers
- Data protection strategies

**Live Demo Flow:**
1. SQL DB elastic pools
2. Cosmos DB multi-region
3. Storage account lifecycle
4. Azure Backup vaults

## Hour 3 (1:09-2:00) - Infrastructure Patterns That Matter
**Theme: "Modern App Architecture Patterns"**
- Container Apps vs AKS decision tree
- Event-driven architecture patterns
- API Management as a front door
- Integration patterns with Logic Apps

**Live Demo Flow:**
1. Container Apps with Dapr
2. Event Grid custom topics
3. APIM with OAuth2
4. Logic Apps with managed identity

## Hour 4 (2:09-3:00) - The Network is the Computer
**Theme: "Zero Trust Networking"**
- Hub-spoke vs Virtual WAN
- Private Link vs Service Endpoints
- Load Balancer vs App Gateway
- Network Security Groups best practices

**Live Demo Flow:**
1. Hub-spoke with Azure CLI
2. Private Link service setup
3. Application Gateway WAF
4. NSG flow logs analysis

## Hour 5 (3:09-4:00) - Business Continuity & Governance
**Theme: "Always Available, Always Compliant"**
- Azure Policy as Code
- Management group hierarchy
- Cross-region HA patterns
- Cost optimization techniques

**Live Demo Flow:**
1. Policy initiatives with Bicep
2. Management group structure
3. Traffic Manager profiles
4. Cost Management budgets

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
