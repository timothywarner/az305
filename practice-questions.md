# AZ-305 Practice Questions - After Segment Learning Review

## Segment 1: Identity, Governance & Monitoring

### Identity & Authorization

1. **Q**: Contoso Ltd., a global manufacturing company, needs to allow their suppliers to access specific Azure resources for inventory management. The solution must support single sign-on and maintain security. Which solution should you recommend?

   - A. Microsoft Entra External ID
   - B. Microsoft Entra B2B
   - C. Microsoft Entra External Identities
   - D. Microsoft Entra Guest Users

   **Correct Answer**: B

   **Explanation**:
   - **Correct**: Microsoft Entra B2B is designed for business-to-business collaboration, allowing Contoso's suppliers to access specific Azure resources with their own credentials while maintaining security. [Learn more](https://learn.microsoft.com/azure/active-directory/external-identities/what-is-b2b)
   - **Incorrect A**: Microsoft Entra External ID is designed for customer-facing applications, not for business-to-business collaboration with suppliers.
   - **Incorrect C**: Microsoft Entra External Identities is a broader term that includes both B2B and External ID capabilities.
   - **Incorrect D**: Microsoft Entra Guest Users is a feature within B2B, not a standalone solution.

2. **Q**: Wingtip Toys, an e-commerce company, needs to securely store and manage SSL certificates for their customer-facing websites, API keys for third-party services, and database connection strings. Which service should you recommend?

   - A. Azure Key Vault with Private Link
   - B. Azure Storage Account with encryption
   - C. Azure App Configuration
   - D. Microsoft Entra Managed Identity

   **Correct Answer**: A

   **Explanation**:
   - **Correct**: Azure Key Vault with Private Link provides secure access to Wingtip's secrets, certificates, and keys without exposing them to the public internet, which is crucial for an e-commerce platform. [Learn more](https://learn.microsoft.com/azure/key-vault/general/private-link-service)
   - **Incorrect B**: Azure Storage Account with encryption is for storing data, not specifically for managing secrets, certificates, and keys.
   - **Incorrect C**: Azure App Configuration is for managing application settings, not for managing secrets, certificates, and keys.
   - **Incorrect D**: Microsoft Entra Managed Identity is for authentication, not for managing secrets, certificates, and keys.

3. **Q**: Fabrikam, a financial services company, needs to implement comprehensive monitoring for their Azure resources, including VMs, databases, and web applications. The solution must provide detailed metrics, logs, and alerting capabilities. Which service should you recommend?

   - A. Azure Monitor with Log Analytics
   - B. Azure Application Insights
   - C. Azure Network Watcher
   - D. Microsoft Defender for Cloud

   **Correct Answer**: A

   **Explanation**:
   - **Correct**: Azure Monitor with Log Analytics provides comprehensive monitoring capabilities for Fabrikam's Azure resources, including metrics, logs, and alerts, which is essential for a financial services company. [Learn more](https://learn.microsoft.com/azure/azure-monitor/logs/log-analytics-overview)
   - **Incorrect B**: Azure Application Insights is specifically for monitoring applications, not all Azure resources.
   - **Incorrect C**: Azure Network Watcher is specifically for monitoring network resources, not all Azure resources.
   - **Incorrect D**: Microsoft Defender for Cloud is specifically for security monitoring, not all Azure resources.

### Governance

4. **Q**: Contoso Ltd. needs to implement a solution for managing compliance with industry regulations (GDPR, ISO 27001) across their Azure resources. The solution must allow for policy creation, assignment, and monitoring. Which service should you recommend?

   - A. Azure Policy
   - B. Azure Blueprints
   - C. Azure Management Groups
   - D. Azure Resource Graph

   **Correct Answer**: A

   **Explanation**:
   - **Correct**: Azure Policy allows Contoso to create, assign, and manage policies to enforce compliance standards across their Azure resources, which is crucial for meeting GDPR and ISO 27001 requirements. [Learn more](https://learn.microsoft.com/azure/governance/policy/overview)
   - **Incorrect B**: Azure Blueprints is for packaging and deploying compliance standards, not for managing compliance.
   - **Incorrect C**: Azure Management Groups are for organizing resources, not for managing compliance.
   - **Incorrect D**: Azure Resource Graph is for querying resources, not for managing compliance.

5. **Q**: Wingtip Toys needs to implement a solution for resource tagging in Azure to track costs, departments, and environments across their resources. The solution must enforce tagging standards automatically. Which service should you recommend?

   - A. Azure Policy
   - B. Azure Tags
   - C. Azure Resource Graph
   - D. Azure Management Groups

   **Correct Answer**: A

   **Explanation**:
   - **Correct**: Azure Policy can be used to enforce tagging standards across Wingtip's Azure resources, ensuring consistent resource organization and cost tracking. [Learn more](https://learn.microsoft.com/azure/governance/policy/how-to/manage-tags)
   - **Incorrect B**: Azure Tags is a feature, not a service for enforcing tagging standards.
   - **Incorrect C**: Azure Resource Graph is for querying resources, not for enforcing tagging standards.
   - **Incorrect D**: Azure Management Groups are for organizing resources, not for enforcing tagging standards.

## Segment 2: Data Storage Solutions

### Relational Data

6. **Q**: Fabrikam needs to implement a solution for storing customer transaction data in Azure. The data is highly structured and requires ACID compliance. Which service should you recommend?

   - A. Azure SQL Database
   - B. Azure Cosmos DB
   - C. Azure Table Storage
   - D. Azure Blob Storage

   **Correct Answer**: A

   **Explanation**:
   - **Correct**: Azure SQL Database is designed for relational data like customer transactions, providing ACID compliance and a fully managed SQL database service. [Learn more](https://learn.microsoft.com/azure/azure-sql/database/sql-database-paas-overview)
   - **Incorrect B**: Azure Cosmos DB is designed for NoSQL data, not specifically for relational data requiring ACID compliance.
   - **Incorrect C**: Azure Table Storage is designed for NoSQL data, not specifically for relational data requiring ACID compliance.
   - **Incorrect D**: Azure Blob Storage is designed for unstructured data, not for relational data.

7. **Q**: Contoso Ltd. needs to implement a solution for database scalability in Azure to handle varying workloads across multiple databases. The solution must be cost-effective. Which service should you recommend?

   - A. Azure SQL Database with elastic pools
   - B. Azure Cosmos DB with autoscale
   - C. Azure Table Storage with partitioning
   - D. Azure Blob Storage with tiering

   **Correct Answer**: A

   **Explanation**:
   - **Correct**: Azure SQL Database with elastic pools provides cost-effective scalability for Contoso's multiple databases with varying and unpredictable usage patterns. [Learn more](https://learn.microsoft.com/azure/azure-sql/database/elastic-pool-overview)
   - **Incorrect B**: Azure Cosmos DB with autoscale is for NoSQL databases, not specifically for relational databases.
   - **Incorrect C**: Azure Table Storage with partitioning is for NoSQL databases, not specifically for relational databases.
   - **Incorrect D**: Azure Blob Storage with tiering is for unstructured data, not for relational databases.

### Semi-Structured and Unstructured Data

8. **Q**: Wingtip Toys needs to implement a solution for storing product catalog data in Azure. The data includes JSON documents with varying schemas and requires global distribution. Which service should you recommend?

   - A. Azure Cosmos DB
   - B. Azure SQL Database
   - C. Azure Table Storage
   - D. Azure Blob Storage

   **Correct Answer**: A

   **Explanation**:
   - **Correct**: Azure Cosmos DB is designed for semi-structured data like product catalogs, providing global distribution and schema flexibility. [Learn more](https://learn.microsoft.com/azure/cosmos-db/introduction)
   - **Incorrect B**: Azure SQL Database is designed for relational data, not specifically for semi-structured data with varying schemas.
   - **Incorrect C**: Azure Table Storage is designed for NoSQL data, but not as feature-rich as Cosmos DB for semi-structured data.
   - **Incorrect D**: Azure Blob Storage is designed for unstructured data, not for semi-structured data.

9. **Q**: Fabrikam needs to implement a solution for storing customer documents (PDFs, images, videos) in Azure. The solution must support tiered storage for cost optimization. Which service should you recommend?

   - A. Azure Blob Storage
   - B. Azure Cosmos DB
   - C. Azure SQL Database
   - D. Azure Table Storage

   **Correct Answer**: A

   **Explanation**:
   - **Correct**: Azure Blob Storage is designed for unstructured data like customer documents, providing tiered storage options for cost optimization. [Learn more](https://learn.microsoft.com/azure/storage/blobs/storage-blobs-overview)
   - **Incorrect B**: Azure Cosmos DB is designed for semi-structured data, not specifically for unstructured data like documents.
   - **Incorrect C**: Azure SQL Database is designed for relational data, not for unstructured data.
   - **Incorrect D**: Azure Table Storage is designed for NoSQL data, not specifically for unstructured data.

### Data Integration

10. **Q**: Contoso Ltd. needs to implement a solution for integrating data from multiple sources (on-premises SQL Server, Azure SQL Database, and CSV files) into their data warehouse. Which service should you recommend?

    - A. Azure Data Factory
    - B. Azure Synapse Analytics
    - C. Azure Databricks
    - D. Azure HDInsight

    **Correct Answer**: A

    **Explanation**:
    - **Correct**: Azure Data Factory is a cloud-based data integration service that allows Contoso to create data-driven workflows for orchestrating and automating data movement and transformation from multiple sources. [Learn more](https://learn.microsoft.com/azure/data-factory/introduction)
    - **Incorrect B**: Azure Synapse Analytics is for data warehousing and analytics, not specifically for data integration.
    - **Incorrect C**: Azure Databricks is for big data analytics, not specifically for data integration.
    - **Incorrect D**: Azure HDInsight is for big data processing, not specifically for data integration.

## Segment 3: Business Continuity

### Backup and Disaster Recovery

11. **Q**: Wingtip Toys needs to implement a solution for backing up their Azure VMs and SQL databases. The solution must support long-term retention and point-in-time recovery. Which service should you recommend?

    - A. Azure Backup
    - B. Azure Site Recovery
    - C. Azure Storage Replication
    - D. Azure Traffic Manager

    **Correct Answer**: A

    **Explanation**:
    - **Correct**: Azure Backup provides a simple, secure, and cost-effective solution to back up Wingtip's VMs and SQL databases with long-term retention and point-in-time recovery capabilities. [Learn more](https://learn.microsoft.com/azure/backup/backup-overview)
    - **Incorrect B**: Azure Site Recovery is for disaster recovery, not specifically for backup.
    - **Incorrect C**: Azure Storage Replication is for data redundancy, not specifically for backup.
    - **Incorrect D**: Azure Traffic Manager is for traffic routing, not for backup.

12. **Q**: Fabrikam needs to implement a solution for disaster recovery of their critical financial applications. The solution must support automated failover and minimal data loss. Which service should you recommend?

    - A. Azure Site Recovery
    - B. Azure Backup
    - C. Azure Storage Replication
    - D. Azure Traffic Manager

    **Correct Answer**: A

    **Explanation**:
    - **Correct**: Azure Site Recovery provides disaster recovery and business continuity for Fabrikam's critical financial applications by replicating workloads and supporting automated failover with minimal data loss. [Learn more](https://learn.microsoft.com/azure/site-recovery/site-recovery-overview)
    - **Incorrect B**: Azure Backup is for data backup, not specifically for disaster recovery.
    - **Incorrect C**: Azure Storage Replication is for data redundancy, not specifically for disaster recovery.
    - **Incorrect D**: Azure Traffic Manager is for traffic routing, not for disaster recovery.

### High Availability

13. **Q**: Contoso Ltd. needs to implement a solution for high availability of their manufacturing applications. The solution must protect against datacenter failures. Which service should you recommend?

    - A. Azure Availability Zones
    - B. Azure Availability Sets
    - C. Azure Load Balancer
    - D. Azure Traffic Manager

    **Correct Answer**: A

    **Explanation**:
    - **Correct**: Azure Availability Zones provide high availability for Contoso's manufacturing applications by offering unique physical locations within an Azure region, each with its own independent power, cooling, and networking. [Learn more](https://learn.microsoft.com/azure/availability-zones/az-overview)
    - **Incorrect B**: Azure Availability Sets provide high availability within a single datacenter, not across multiple datacenters.
    - **Incorrect C**: Azure Load Balancer distributes traffic, but doesn't provide high availability across datacenters.
    - **Incorrect D**: Azure Traffic Manager routes traffic, but doesn't provide high availability across datacenters.

14. **Q**: Wingtip Toys needs to implement a solution for load balancing their e-commerce applications. The solution must support SSL termination and web application firewall capabilities. Which service should you recommend?

    - A. Azure Application Gateway
    - B. Azure Load Balancer
    - C. Azure Front Door
    - D. Azure Traffic Manager

    **Correct Answer**: A

    **Explanation**:
    - **Correct**: Azure Application Gateway provides SSL termination, web application firewall, and load balancing capabilities for Wingtip's e-commerce applications. [Learn more](https://learn.microsoft.com/azure/application-gateway/overview)
    - **Incorrect B**: Azure Load Balancer is a general-purpose load balancer without SSL termination or WAF capabilities.
    - **Incorrect C**: Azure Front Door is a global, scalable entry-point service, not specifically for SSL termination and WAF.
    - **Incorrect D**: Azure Traffic Manager is a DNS-based traffic load balancer, not for SSL termination and WAF.

## Segment 4: Infrastructure Solutions

### Compute Solutions

15. **Q**: Fabrikam needs to implement a solution for running their microservices-based financial applications in containers. The solution must support automatic scaling and managed Kubernetes. Which service should you recommend?

    - A. Azure Kubernetes Service
    - B. Azure Container Apps
    - C. Azure Container Instances
    - D. Azure App Service

    **Correct Answer**: A

    **Explanation**:
    - **Correct**: Azure Kubernetes Service provides managed Kubernetes for Fabrikam's microservices, supporting automatic scaling and enterprise-grade features needed for financial applications. [Learn more](https://learn.microsoft.com/azure/aks/intro-kubernetes)
    - **Incorrect B**: Azure Container Apps is for simpler containerized applications, not specifically for complex microservices requiring Kubernetes.
    - **Incorrect C**: Azure Container Instances is for running individual containers, not for managing microservices.
    - **Incorrect D**: Azure App Service is for web applications, not specifically for containerized microservices.

16. **Q**: Your organization needs to implement a solution for serverless compute in Azure. Which service should you recommend?

    - A. Azure Functions
    - B. Azure Logic Apps
    - C. Azure WebJobs
    - D. Azure App Service

    **Correct Answer**: A

    **Explanation**:
    - **Correct**: Azure Functions is a serverless compute service that enables you to run event-driven code without managing infrastructure. [Learn more](https://learn.microsoft.com/azure/azure-functions/functions-overview)
    - **Incorrect B**: Azure Logic Apps is for workflow automation, not specifically for serverless compute.
    - **Incorrect C**: Azure WebJobs is for background tasks in App Service, not a standalone serverless compute service.
    - **Incorrect D**: Azure App Service is for web applications, not specifically for serverless compute.

### Application Architecture

17. **Q**: Your organization needs to implement a solution for event-driven architecture in Azure. Which service should you recommend?

    - A. Azure Event Grid
    - B. Azure Event Hubs
    - C. Azure Service Bus
    - D. Azure Logic Apps

    **Correct Answer**: A

    **Explanation**:
    - **Correct**: Azure Event Grid is a fully managed event routing service that enables you to build event-driven applications. [Learn more](https://learn.microsoft.com/azure/event-grid/overview)
    - **Incorrect B**: Azure Event Hubs is for big data streaming, not specifically for event-driven architecture.
    - **Incorrect C**: Azure Service Bus is for message queuing, not specifically for event-driven architecture.
    - **Incorrect D**: Azure Logic Apps is for workflow automation, not specifically for event-driven architecture.

18. **Q**: Your organization needs to implement a solution for API integration in Azure. Which service should you recommend?

    - A. Azure API Management
    - B. Azure Functions
    - C. Azure Logic Apps
    - D. Azure App Service

    **Correct Answer**: A

    **Explanation**:
    - **Correct**: Azure API Management provides a complete solution for publishing, securing, transforming, maintaining, and monitoring APIs. [Learn more](https://learn.microsoft.com/azure/api-management/api-management-key-concepts)
    - **Incorrect B**: Azure Functions is for serverless compute, not specifically for API management.
    - **Incorrect C**: Azure Logic Apps is for workflow automation, not specifically for API management.
    - **Incorrect D**: Azure App Service is for web applications, not specifically for API management.

### Migrations

19. **Q**: Your organization needs to implement a solution for migrating workloads to Azure. Which service should you recommend?

    - A. Azure Migrate
    - B. Azure Site Recovery
    - C. Azure Data Box
    - D. Azure Storage Migration

    **Correct Answer**: A

    **Explanation**:
    - **Correct**: Azure Migrate provides a centralized hub to assess and migrate on-premises servers, infrastructure, applications, and data to Azure. [Learn more](https://learn.microsoft.com/azure/migrate/migrate-services-overview)
    - **Incorrect B**: Azure Site Recovery is for disaster recovery, not specifically for migration.
    - **Incorrect C**: Azure Data Box is for data transfer, not specifically for workload migration.
    - **Incorrect D**: Azure Storage Migration is for migrating storage, not specifically for workload migration.

20. **Q**: Your organization needs to implement a solution for migrating databases to Azure. Which service should you recommend?

    - A. Azure Database Migration Service
    - B. Azure Site Recovery
    - C. Azure Data Box
    - D. Azure Storage Migration

    **Correct Answer**: A

    **Explanation**:
    - **Correct**: Azure Database Migration Service provides a seamless, fully automated migration experience from multiple database sources to Azure data platforms. [Learn more](https://learn.microsoft.com/azure/dms/dms-overview)
    - **Incorrect B**: Azure Site Recovery is for disaster recovery, not specifically for database migration.
    - **Incorrect C**: Azure Data Box is for data transfer, not specifically for database migration.
    - **Incorrect D**: Azure Storage Migration is for migrating storage, not specifically for database migration.

## Segment 5: Network Solutions

### Connectivity Solutions

21. **Q**: Your organization needs to implement a solution for connecting Azure resources to on-premises networks. Which service should you recommend?

    - A. Azure ExpressRoute
    - B. Azure VPN Gateway
    - C. Azure Virtual WAN
    - D. Azure Front Door

    **Correct Answer**: A

    **Explanation**:
    - **Correct**: Azure ExpressRoute provides private connectivity to Azure services through a dedicated connection facilitated by a connectivity provider. [Learn more](https://learn.microsoft.com/azure/expressroute/expressroute-introduction)
    - **Incorrect B**: Azure VPN Gateway provides secure connectivity over the public internet, not private connectivity.
    - **Incorrect C**: Azure Virtual WAN is for connecting multiple networks, not specifically for connecting to on-premises networks.
    - **Incorrect D**: Azure Front Door is for global routing, not for connecting to on-premises networks.

22. **Q**: Your organization needs to implement a solution for connecting Azure resources to the internet. Which service should you recommend?

    - A. Azure Public IP
    - B. Azure Private Link
    - C. Azure Service Endpoints
    - D. Azure Virtual Network

    **Correct Answer**: A

    **Explanation**:
    - **Correct**: Azure Public IP provides a public IP address that can be assigned to Azure resources to enable internet connectivity. [Learn more](https://learn.microsoft.com/azure/virtual-network/public-ip-addresses)
    - **Incorrect B**: Azure Private Link is for private connectivity, not for internet connectivity.
    - **Incorrect C**: Azure Service Endpoints are for connecting to Azure services, not for internet connectivity.
    - **Incorrect D**: Azure Virtual Network is for creating a private network, not for internet connectivity.

### Network Optimization

23. **Q**: Your organization needs to implement a solution for optimizing network performance in Azure. Which service should you recommend?

    - A. Azure CDN
    - B. Azure Front Door
    - C. Azure Traffic Manager
    - D. Azure Load Balancer

    **Correct Answer**: A

    **Explanation**:
    - **Correct**: Azure CDN provides a global content delivery network for delivering high-bandwidth content to users by caching content at strategically placed locations. [Learn more](https://learn.microsoft.com/azure/cdn/cdn-overview)
    - **Incorrect B**: Azure Front Door is for global routing, not specifically for content delivery.
    - **Incorrect C**: Azure Traffic Manager is for DNS-based traffic routing, not specifically for content delivery.
    - **Incorrect D**: Azure Load Balancer is for distributing traffic, not specifically for content delivery.

24. **Q**: Your organization needs to implement a solution for optimizing network security in Azure. Which service should you recommend?

    - A. Azure Firewall
    - B. Azure DDoS Protection
    - C. Azure WAF
    - D. Azure Network Security Groups

    **Correct Answer**: A

    **Explanation**:
    - **Correct**: Azure Firewall is a managed, cloud-based network security service that protects your Azure Virtual Network resources. [Learn more](https://learn.microsoft.com/azure/firewall/overview)
    - **Incorrect B**: Azure DDoS Protection is specifically for protecting against DDoS attacks, not for general network security.
    - **Incorrect C**: Azure WAF is specifically for protecting web applications, not for general network security.
    - **Incorrect D**: Azure Network Security Groups are for filtering network traffic, not for comprehensive network security.

### Load Balancing and Routing

25. **Q**: Your organization needs to implement a solution for load balancing and routing in Azure. Which service should you recommend?

    - A. Azure Application Gateway
    - B. Azure Load Balancer
    - C. Azure Front Door
    - D. Azure Traffic Manager

    **Correct Answer**: A

    **Explanation**:
    - **Correct**: Azure Application Gateway is a web traffic load balancer that enables you to manage traffic to your web applications. [Learn more](https://learn.microsoft.com/azure/application-gateway/overview)
    - **Incorrect B**: Azure Load Balancer is for general-purpose load balancing, not specifically for web traffic.
    - **Incorrect C**: Azure Front Door is for global routing, not specifically for web traffic load balancing.
    - **Incorrect D**: Azure Traffic Manager is for DNS-based traffic routing, not specifically for web traffic load balancing.

## Additional Practice Resources

1. **Microsoft Learn Practice Assessments**
   - [AZ-305 Practice Assessment](https://learn.microsoft.com/certifications/exams/az-305/practice/assessment)

2. **Third-Party Practice Exams**
   - [MeasureUp AZ-305 Practice Exams](https://www.measureup.com/microsoft-az-305-practice-test-designing-azure-infrastructure-solutions.html)
   - [Whizlabs AZ-305 Practice Exams](https://www.whizlabs.com/designing-microsoft-azure-infrastructure-solutions-az-305/)

3. **Study Guides**
   - [Microsoft AZ-305 Study Guide](https://learn.microsoft.com/credentials/certifications/resources/study-guides/az-305)
   - [Azure Architecture Center](https://learn.microsoft.com/azure/architecture/) 