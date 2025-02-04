# 🔬 Lab Environment Setup

## Free Azure Access Options

1. **[Azure Free Account](https://azure.microsoft.com/free/)**
   - $200 credit for 30 days
   - 55+ always-free services
   - Key free services for AZ-305:
     - Azure Active Directory (free tier)
     - Azure Virtual Networks
     - Azure Key Vault (750 hours)
     - Azure Functions (1M requests)

2. **Training Platforms with Free Azure Labs**
   - [Microsoft Learn Sandbox](https://learn.microsoft.com/training/)
   - [Azure Citadel](https://azurecitadel.com/)
   - [Azure Log Analytics Demo](https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-demo-environment)
   - [Azure DevOps Demo Generator](https://azuredevopsdemogenerator.azurewebsites.net/)

## 📐 Architecture Resources

### Microsoft Well-Architected Framework
- [Azure WAF](https://learn.microsoft.com/azure/well-architected/) - Core framework
- [AWS WAF](https://aws.amazon.com/architecture/well-architected/) - Compare/contrast
- [Google Cloud Architecture Framework](https://cloud.google.com/architecture/framework) - Compare/contrast

### Cloud Adoption Framework
- [Azure CAF](https://learn.microsoft.com/azure/cloud-adoption-framework/)
- [AWS CAF](https://aws.amazon.com/cloud-adoption-framework/)
- [Google Cloud Adoption Framework](https://cloud.google.com/adoption-framework)

### Reference Architectures
- [Azure Architecture Center](https://learn.microsoft.com/azure/architecture/)
- [Azure Solution Ideas](https://learn.microsoft.com/azure/architecture/browse/)
- [Azure Reference Architectures](https://learn.microsoft.com/azure/architecture/browse/reference-architectures)
- [Azure Example Scenarios](https://learn.microsoft.com/azure/architecture/browse/example-scenarios)

## 🎯 Exam-Focused Lab Areas

1. **Identity & Governance**
   - Azure AD tenant setup
   - RBAC configurations
   - Policy assignments
   - Management groups

2. **Data Storage**
   - Storage accounts
   - SQL databases
   - Cosmos DB
   - Data protection options

3. **Business Continuity**
   - Backup vaults
   - Site recovery
   - Availability sets/zones
   - Load balancers

4. **Infrastructure**
   - Virtual networks
   - App Service plans
   - Container instances
   - Serverless functions

## 💡 Real-World Focus Areas

1. **Cost Management**
   - Use [Azure Pricing Calculator](https://azure.microsoft.com/pricing/calculator/)
   - Enable cost alerts
   - Review [Azure Cost Optimization Guide](https://learn.microsoft.com/azure/cost-management-billing/costs/cost-mgt-best-practices)

2. **Security Baseline**
   - [Azure Security Benchmark](https://learn.microsoft.com/security/benchmark/azure/)
   - [Security Center](https://learn.microsoft.com/azure/security-center/)
   - [Microsoft Defender for Cloud](https://learn.microsoft.com/azure/defender-for-cloud/)

3. **Monitoring & Operations**
   - Azure Monitor
   - Log Analytics
   - Application Insights
   - Network Watcher

## 🚀 Getting Started

1. Create Azure Free Account
2. Enable MFA
3. Install required tools:
   - Azure CLI
   - PowerShell 7
   - VS Code + Azure Extensions
   - Azure Storage Explorer

## ⚠️ Resource Constraints (Free Tier)

- VM sizes: B1s, B1ls only
- Storage: 5GB LRS Blob
- Database: Basic tier only
- Functions: 1M executions
- Bandwidth: 15GB outbound

## 💰 Cost Control Tips

1. Use [Azure Advisor](https://learn.microsoft.com/azure/advisor/)
2. Set spending limits
3. Clean up after labs
4. Use auto-shutdown for VMs
5. Leverage consumption-based services 