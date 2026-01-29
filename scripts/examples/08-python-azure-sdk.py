"""
Title:       AZ-305 Python Azure SDK Reference Examples
Domains:     AZ-305 Domains 1-4 (Identity, Data, Business Continuity, Infrastructure)
Description: Python examples demonstrating Azure SDK patterns for identity,
             resource management, data operations, monitoring, IaC deployment,
             and resilience. Teaching examples for code review -- not a single
             runnable script.
Author:      Tim Warner
Date:        January 2026
Reference:   https://learn.microsoft.com/azure/developer/python/sdk/azure-sdk-overview

Required packages (pip install):
    azure-identity
    azure-mgmt-resource
    azure-keyvault-secrets
    azure-cosmos
    azure-storage-blob
    azure-servicebus
    azure-monitor-query
    azure-mgmt-monitor
    azure-eventgrid
    opentelemetry-sdk
    azure-monitor-opentelemetry
    tenacity
    pyodbc
"""

from __future__ import annotations

import os
import json
import logging
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Any

# ============================================================================
# SECTION A: IDENTITY AND AUTHENTICATION
# ============================================================================


def demonstrate_default_credential() -> None:
    """Show the DefaultAzureCredential chain and when each credential fires.

    WHEN TO USE: DefaultAzureCredential is the recommended starting point
    for ALL Azure SDK authentication. It tries credentials in order:
      1. EnvironmentCredential (service principal env vars)
      2. WorkloadIdentityCredential (Kubernetes pods)
      3. ManagedIdentityCredential (Azure VMs, App Service, Functions)
      4. AzureDeveloperCliCredential (azd auth login)
      5. AzureCliCredential (az login -- local development)
      6. AzurePowerShellCredential (Connect-AzAccount)
      7. InteractiveBrowserCredential (disabled by default)

    EXAM TIP: AZ-305 expects you to recommend DefaultAzureCredential for
    development and ManagedIdentityCredential for production workloads.
    Never use client secrets in application code -- use managed identity.
    """
    from azure.identity import DefaultAzureCredential

    # The credential chain evaluates lazily -- no network call until token needed
    credential = DefaultAzureCredential(
        # Exclude credentials not relevant to your environment for faster auth
        exclude_shared_token_cache_credential=True,
        # For user-assigned managed identity, specify the client ID:
        # managed_identity_client_id="00000000-0000-0000-0000-000000000000"
    )

    # Enable logging to see which credential in the chain succeeded
    logging.basicConfig(level=logging.DEBUG)
    logger = logging.getLogger("azure.identity")
    logger.setLevel(logging.DEBUG)

    return credential


def demonstrate_managed_identity() -> None:
    """Authenticate using Managed Identity -- the production best practice.

    WHEN TO USE: Any Azure-hosted workload (VMs, App Service, Functions,
    Container Apps, AKS pods). Eliminates credential management entirely.

    EXAM TIP: System-assigned managed identity is tied to the resource lifecycle.
    User-assigned managed identity can be shared across resources -- use it
    when multiple services need the same permissions (e.g., App Service +
    Function App both accessing the same Key Vault).
    """
    from azure.identity import ManagedIdentityCredential

    # System-assigned managed identity (no parameters needed)
    system_credential = ManagedIdentityCredential()

    # User-assigned managed identity (specify client_id)
    user_assigned_client_id = os.environ.get("AZURE_MANAGED_IDENTITY_CLIENT_ID", "")
    user_credential = ManagedIdentityCredential(client_id=user_assigned_client_id)

    return system_credential, user_credential


def demonstrate_service_principal() -> None:
    """Authenticate using a service principal -- for CI/CD pipelines.

    WHEN TO USE: GitHub Actions, Azure DevOps pipelines, or external systems
    that cannot use managed identity. Prefer workload identity federation
    (federated credentials) over client secrets when possible.

    EXAM TIP: AZ-305 recommends workload identity federation for CI/CD
    over client secrets. Federation uses OIDC tokens from GitHub/Azure DevOps
    and eliminates secret rotation entirely.
    """
    from azure.identity import ClientSecretCredential

    # NEVER hardcode these values -- always use environment variables or Key Vault
    tenant_id = os.environ["AZURE_TENANT_ID"]
    client_id = os.environ["AZURE_CLIENT_ID"]
    client_secret = os.environ["AZURE_CLIENT_SECRET"]

    credential = ClientSecretCredential(
        tenant_id=tenant_id,
        client_id=client_id,
        client_secret=client_secret,
    )

    return credential


def retrieve_secret_from_key_vault(vault_url: str, secret_name: str) -> str:
    """Retrieve a secret from Azure Key Vault using azure-keyvault-secrets.

    WHEN TO USE: Centralized secret management for connection strings, API keys,
    and certificates. Key Vault is the only approved secret store for AZ-305.

    EXAM TIP: AZ-305 always prefers Key Vault references over direct secrets.
    For App Service, use Key Vault References in app settings (no code changes).
    For Bicep/ARM, use Key Vault parameter references at deployment time.
    """
    from azure.identity import DefaultAzureCredential
    from azure.keyvault.secrets import SecretClient

    credential = DefaultAzureCredential()
    client = SecretClient(vault_url=vault_url, credential=credential)

    try:
        secret = client.get_secret(secret_name)
        logging.info("Retrieved secret '%s', created on %s", secret.name, secret.properties.created_on)
        return secret.value
    except Exception as exc:
        logging.error("Failed to retrieve secret '%s': %s", secret_name, exc)
        raise


# ============================================================================
# SECTION B: RESOURCE MANAGEMENT PATTERNS
# ============================================================================


@dataclass(frozen=True)
class ResourceGroupConfig:
    """Immutable configuration for resource group creation.

    EXAM TIP: Tags are essential for cost allocation, governance, and
    automation. AZ-305 recommends enforcing required tags via Azure Policy
    with a 'Require a tag and its value' built-in policy definition.
    """
    name: str
    location: str
    tags: dict[str, str] = field(default_factory=lambda: {
        "environment": "production",
        "costCenter": "IT-12345",
        "owner": "platform-team@contoso.com",
        "managedBy": "bicep",
    })


def create_resource_group(config: ResourceGroupConfig) -> dict[str, Any]:
    """Create a resource group with required governance tags.

    WHEN TO USE: Programmatic resource provisioning in automation scripts
    or custom deployment tooling. For most scenarios, use Bicep/ARM templates
    deployed via CI/CD instead.
    """
    from azure.identity import DefaultAzureCredential
    from azure.mgmt.resource import ResourceManagementClient

    credential = DefaultAzureCredential()
    subscription_id = os.environ["AZURE_SUBSCRIPTION_ID"]
    client = ResourceManagementClient(credential, subscription_id)

    rg_result = client.resource_groups.create_or_update(
        config.name,
        {"location": config.location, "tags": config.tags},
    )

    return {
        "name": rg_result.name,
        "location": rg_result.location,
        "provisioning_state": rg_result.properties.provisioning_state,
        "tags": rg_result.tags,
    }


def query_resource_graph(query: str) -> list[dict[str, Any]]:
    """Run an Azure Resource Graph query for cross-subscription inventory.

    WHEN TO USE: Inventory queries spanning multiple subscriptions. Resource
    Graph is faster than ARM enumeration APIs and supports complex joins.

    EXAM TIP: Resource Graph queries use KQL syntax but operate on a different
    data store than Log Analytics. Use Resource Graph for resource inventory
    (current state) and Log Analytics for time-series operational data.
    """
    from azure.identity import DefaultAzureCredential
    from azure.mgmt.resourcegraph import ResourceGraphClient
    from azure.mgmt.resourcegraph.models import QueryRequest

    credential = DefaultAzureCredential()
    client = ResourceGraphClient(credential)

    # Example query: find all VMs without the "environment" tag
    # Resources
    # | where type == "microsoft.compute/virtualmachines"
    # | where isnull(tags.environment)
    # | project name, resourceGroup, location

    request = QueryRequest(query=query)
    response = client.resources(request)

    return [row for row in response.data]


# ============================================================================
# SECTION C: DATA OPERATIONS
# ============================================================================


def connect_sql_with_token_auth(server: str, database: str) -> None:
    """Connect to Azure SQL Database using Microsoft Entra token auth (no passwords).

    WHEN TO USE: All Azure SQL connections from application code. Token-based
    auth with managed identity eliminates password management and rotation.

    EXAM TIP: AZ-305 ALWAYS recommends Microsoft Entra authentication for
    Azure SQL over SQL authentication. Set the Azure SQL server to
    'Microsoft Entra-only authentication' to enforce this.
    """
    import struct
    import pyodbc
    from azure.identity import DefaultAzureCredential

    credential = DefaultAzureCredential()

    # Get token for Azure SQL Database resource
    token = credential.get_token("https://database.windows.net/.default")
    token_bytes = token.token.encode("utf-16-le")
    token_struct = struct.pack(f"<I{len(token_bytes)}s", len(token_bytes), token_bytes)

    connection_string = (
        f"DRIVER={{ODBC Driver 18 for SQL Server}};"
        f"SERVER={server}.database.windows.net;"
        f"DATABASE={database};"
        f"Encrypt=yes;"
    )

    conn = pyodbc.connect(connection_string, attrs_before={1256: token_struct})

    try:
        cursor = conn.cursor()
        cursor.execute("SELECT @@VERSION")
        row = cursor.fetchone()
        logging.info("Connected to SQL: %s", row[0])
    finally:
        conn.close()


def cosmos_db_crud_with_partition_strategy(endpoint: str, database_name: str) -> None:
    """Cosmos DB CRUD operations demonstrating partition key strategy.

    WHEN TO USE: NoSQL workloads requiring single-digit millisecond latency
    at global scale. Cosmos DB excels for real-time apps, IoT, and gaming.

    EXAM TIP: Partition key selection is the most critical Cosmos DB design
    decision. Choose a key with high cardinality, even distribution, and
    that matches your most frequent query filter. Bad partition keys cause
    hot partitions and RU throttling (429 errors).

    ALTERNATIVE: For relational data with complex joins, use Azure SQL.
    For document storage without global distribution needs, consider
    Azure SQL with JSON columns or PostgreSQL with JSONB.
    """
    from azure.identity import DefaultAzureCredential
    from azure.cosmos import CosmosClient, PartitionKey, exceptions

    credential = DefaultAzureCredential()
    client = CosmosClient(endpoint, credential=credential)

    # Create database (idempotent)
    database = client.create_database_if_not_exists(id=database_name)

    # Create container with partition key strategy
    # EXAM TIP: /tenantId is a good partition key for multi-tenant SaaS apps.
    # It ensures tenant data co-locality and enables efficient single-partition queries.
    container = database.create_container_if_not_exists(
        id="orders",
        partition_key=PartitionKey(path="/tenantId"),
        offer_throughput=400,  # Minimum provisioned RUs; use autoscale for production
    )

    # Create (point write -- 5-10 RUs typically)
    order = {
        "id": "order-2026-001",
        "tenantId": "contoso",
        "customerId": "cust-100",
        "total": 299.99,
        "status": "pending",
        "createdAt": datetime.now(timezone.utc).isoformat(),
    }

    try:
        container.create_item(body=order)
    except exceptions.CosmosResourceExistsError:
        logging.warning("Order %s already exists", order["id"])

    # Read (point read -- 1 RU; most efficient Cosmos DB operation)
    # EXAM TIP: Point reads (by id + partition key) cost exactly 1 RU for 1KB.
    # This is the cheapest and fastest operation. Design for point reads.
    item = container.read_item(item="order-2026-001", partition_key="contoso")

    # Query within partition (efficient -- scoped to single partition)
    query_results = list(container.query_items(
        query="SELECT * FROM c WHERE c.status = @status",
        parameters=[{"name": "@status", "value": "pending"}],
        partition_key="contoso",
    ))
    logging.info("Found %d pending orders for contoso", len(query_results))

    # Upsert (create or replace -- idempotent write pattern)
    updated_order = {**order, "status": "shipped"}
    container.upsert_item(body=updated_order)


def blob_storage_upload_with_lifecycle_check() -> None:
    """Upload to Blob Storage and check lifecycle management policy.

    WHEN TO USE: Unstructured data storage (documents, images, backups, logs).
    Blob Storage with lifecycle policies automates cost optimization.

    EXAM TIP: Storage account access tiers: Hot (frequent access), Cool
    (infrequent, 30-day minimum), Cold (rare, 90-day minimum), Archive
    (offline, 180-day minimum). AZ-305 tests on choosing tiers based on
    access frequency and latency requirements.
    """
    from azure.identity import DefaultAzureCredential
    from azure.storage.blob import BlobServiceClient

    credential = DefaultAzureCredential()
    account_url = os.environ["AZURE_STORAGE_ACCOUNT_URL"]  # https://<name>.blob.core.windows.net
    client = BlobServiceClient(account_url, credential=credential)

    # Upload a blob
    container_client = client.get_container_client("documents")
    blob_client = container_client.get_blob_client("reports/2026/january-report.pdf")

    sample_data = b"Sample PDF content for demonstration"
    blob_client.upload_blob(
        sample_data,
        overwrite=True,
        metadata={"department": "finance", "classification": "internal"},
        # EXAM TIP: Set access tier at upload time to avoid unnecessary hot-tier charges
        standard_blob_tier="Cool",
    )

    # Check blob properties including access tier
    properties = blob_client.get_blob_properties()
    logging.info(
        "Blob uploaded: tier=%s, size=%d bytes, last_modified=%s",
        properties.blob_tier,
        properties.size,
        properties.last_modified,
    )


def service_bus_send_receive(namespace: str, queue_name: str) -> None:
    """Service Bus message send/receive with sessions and dead-letter handling.

    WHEN TO USE: Enterprise messaging requiring guaranteed delivery, ordering,
    dead-letter handling, and transactions. Use over Storage Queues when you
    need features beyond basic FIFO.

    EXAM TIP: Service Bus vs. Storage Queues vs. Event Grid vs. Event Hubs:
    - Service Bus: Enterprise messaging, ordered delivery, transactions
    - Storage Queues: Simple queue, >80GB capacity, audit trail
    - Event Grid: Event routing (reactive, push-based, near real-time)
    - Event Hubs: High-throughput streaming (millions of events/sec)
    """
    from azure.identity import DefaultAzureCredential
    from azure.servicebus import ServiceBusClient, ServiceBusMessage

    credential = DefaultAzureCredential()
    fully_qualified_namespace = f"{namespace}.servicebus.windows.net"

    # Send message
    with ServiceBusClient(fully_qualified_namespace, credential) as sb_client:
        with sb_client.get_queue_sender(queue_name) as sender:
            message = ServiceBusMessage(
                body=json.dumps({"orderId": "order-2026-001", "action": "process"}),
                content_type="application/json",
                subject="OrderProcessing",
                # EXAM TIP: TimeToLive prevents stale messages from being processed
                time_to_live=timedelta(hours=24),
            )
            sender.send_messages(message)
            logging.info("Sent message to queue '%s'", queue_name)

    # Receive messages
    with ServiceBusClient(fully_qualified_namespace, credential) as sb_client:
        with sb_client.get_queue_receiver(queue_name, max_wait_time=30) as receiver:
            for msg in receiver:
                try:
                    body = json.loads(str(msg))
                    logging.info("Received: %s", body)
                    receiver.complete_message(msg)
                except Exception as exc:
                    logging.error("Processing failed: %s", exc)
                    # EXAM TIP: Dead-letter after max delivery attempts.
                    # Dead-letter queue enables poison message investigation.
                    receiver.dead_letter_message(msg, reason="ProcessingError", error_description=str(exc))


def publish_event_grid_event(topic_endpoint: str) -> None:
    """Publish a custom event to Event Grid.

    WHEN TO USE: Event-driven architectures where producers and consumers
    are decoupled. Event Grid provides push-based delivery with filtering.

    EXAM TIP: Event Grid supports CloudEvents 1.0 schema (industry standard)
    and Event Grid schema. AZ-305 recommends CloudEvents for interoperability.
    """
    from azure.identity import DefaultAzureCredential
    from azure.eventgrid import EventGridPublisherClient
    from azure.core.messaging import CloudEvent

    credential = DefaultAzureCredential()
    client = EventGridPublisherClient(topic_endpoint, credential)

    event = CloudEvent(
        source="/contoso/orders",
        type="Contoso.Orders.OrderCreated",
        data={"orderId": "order-2026-001", "customerId": "cust-100", "total": 299.99},
    )

    client.send([event])
    logging.info("Published CloudEvent to Event Grid topic")


# ============================================================================
# SECTION D: MONITORING AND OBSERVABILITY
# ============================================================================


def setup_opentelemetry_with_azure_monitor() -> None:
    """Configure OpenTelemetry with Azure Monitor exporter.

    WHEN TO USE: All production applications. OpenTelemetry is the
    vendor-neutral standard for distributed tracing, metrics, and logs.
    Azure Monitor OpenTelemetry distro simplifies configuration.

    EXAM TIP: Azure Monitor now recommends OpenTelemetry over the classic
    Application Insights SDKs. The distro auto-collects HTTP requests,
    dependencies, exceptions, and performance counters.
    """
    from azure.monitor.opentelemetry import configure_azure_monitor

    # Single-line setup -- the distro configures traces, metrics, and logs
    configure_azure_monitor(
        # Connection string from Application Insights resource
        connection_string=os.environ["APPLICATIONINSIGHTS_CONNECTION_STRING"],
        # Enable live metrics stream for real-time debugging
        enable_live_metrics=True,
    )

    # After configuration, use standard OpenTelemetry APIs
    from opentelemetry import trace

    tracer = trace.get_tracer(__name__)

    with tracer.start_as_current_span("process-order") as span:
        span.set_attribute("order.id", "order-2026-001")
        span.set_attribute("order.total", 299.99)
        # Business logic here...
        span.add_event("order.validated", {"customerId": "cust-100"})


def query_log_analytics(workspace_id: str, query: str) -> list[dict[str, Any]]:
    """Query Log Analytics workspace using the Azure Monitor Query SDK.

    WHEN TO USE: Programmatic access to log data for custom dashboards,
    automated reporting, or integration with external systems.

    EXAM TIP: The azure-monitor-query SDK supports both logs (KQL) and
    metrics queries. Use LogsQueryClient for KQL, MetricsQueryClient
    for platform metrics. Both support DefaultAzureCredential.
    """
    from azure.identity import DefaultAzureCredential
    from azure.monitor.query import LogsQueryClient, LogsQueryStatus

    credential = DefaultAzureCredential()
    client = LogsQueryClient(credential)

    response = client.query_workspace(
        workspace_id=workspace_id,
        query=query,
        timespan=timedelta(days=1),
    )

    if response.status == LogsQueryStatus.SUCCESS:
        results: list[dict[str, Any]] = []
        for table in response.tables:
            for row in table.rows:
                results.append(dict(zip([col.name for col in table.columns], row)))
        return results
    else:
        logging.error("Query failed: %s", response.partial_error)
        return []


def create_metric_alert_rule(
    resource_group: str,
    alert_name: str,
    target_resource_id: str,
) -> None:
    """Create a metric alert rule via the Azure Monitor Management SDK.

    WHEN TO USE: Automated alert provisioning as part of infrastructure
    deployment. For most cases, define alerts in Bicep/ARM templates instead.

    EXAM TIP: AZ-305 distinguishes between metric alerts (near real-time,
    platform metrics), log alerts (KQL-based, Log Analytics), and activity
    log alerts (control plane operations). Choose based on data source.
    """
    from azure.identity import DefaultAzureCredential
    from azure.mgmt.monitor import MonitorManagementClient
    from azure.mgmt.monitor.models import (
        MetricAlertResource,
        MetricAlertSingleResourceMultipleMetricCriteria,
        MetricCriteria,
    )

    credential = DefaultAzureCredential()
    subscription_id = os.environ["AZURE_SUBSCRIPTION_ID"]
    client = MonitorManagementClient(credential, subscription_id)

    alert = client.metric_alerts.create_or_update(
        resource_group_name=resource_group,
        rule_name=alert_name,
        parameters=MetricAlertResource(
            location="global",
            description="Alert when CPU exceeds 90% for 5 minutes",
            severity=2,
            enabled=True,
            scopes=[target_resource_id],
            evaluation_frequency=timedelta(minutes=5),
            window_size=timedelta(minutes=5),
            criteria=MetricAlertSingleResourceMultipleMetricCriteria(
                all_of=[
                    MetricCriteria(
                        name="HighCPU",
                        metric_name="Percentage CPU",
                        metric_namespace="Microsoft.Compute/virtualMachines",
                        operator="GreaterThan",
                        threshold=90,
                        time_aggregation="Average",
                    )
                ]
            ),
        ),
    )
    logging.info("Created alert rule: %s", alert.name)


# ============================================================================
# SECTION E: INFRASTRUCTURE AS CODE PATTERNS
# ============================================================================


def deploy_bicep_template(
    resource_group: str,
    template_path: str,
    parameters: dict[str, Any],
) -> dict[str, Any]:
    """Deploy a Bicep/ARM template via the Azure SDK with what-if analysis.

    WHEN TO USE: Programmatic deployments from custom tooling. For standard
    CI/CD, use az deployment group create in Azure CLI or the AzureResourceManagerTemplateDeployment
    task in Azure DevOps.

    EXAM TIP: What-if analysis shows predicted changes without deploying.
    AZ-305 recommends running what-if in CI pipelines as a pull request check
    before actual deployment. This prevents unintended resource deletion.
    """
    from azure.identity import DefaultAzureCredential
    from azure.mgmt.resource import ResourceManagementClient
    from azure.mgmt.resource.resources.models import (
        Deployment,
        DeploymentProperties,
        DeploymentMode,
        DeploymentWhatIf,
        DeploymentWhatIfProperties,
    )

    credential = DefaultAzureCredential()
    subscription_id = os.environ["AZURE_SUBSCRIPTION_ID"]
    client = ResourceManagementClient(credential, subscription_id)

    # Read template file
    with open(template_path, "r", encoding="utf-8") as f:
        template_body = json.load(f)

    # Format parameters for ARM API
    formatted_params = {k: {"value": v} for k, v in parameters.items()}

    # Step 1: What-if analysis (preview changes before deploying)
    what_if_result = client.deployments.begin_what_if(
        resource_group_name=resource_group,
        deployment_name="whatif-preview",
        parameters=DeploymentWhatIf(
            properties=DeploymentWhatIfProperties(
                mode=DeploymentMode.INCREMENTAL,
                template=template_body,
                parameters=formatted_params,
            )
        ),
    ).result()

    for change in what_if_result.changes:
        logging.info(
            "What-if: %s %s (%s)",
            change.change_type,
            change.resource_id,
            change.after.type if change.after else "N/A",
        )

    # Step 2: Deploy (with incremental mode to avoid deleting unmanaged resources)
    # EXAM TIP: Incremental mode adds/updates resources. Complete mode DELETES
    # resources not in the template. Always use Incremental unless you want
    # strict template-state enforcement. AZ-305 tests on deployment modes.
    deployment_poller = client.deployments.begin_create_or_update(
        resource_group_name=resource_group,
        deployment_name=f"deploy-{datetime.now(timezone.utc).strftime('%Y%m%d%H%M%S')}",
        parameters=Deployment(
            properties=DeploymentProperties(
                mode=DeploymentMode.INCREMENTAL,
                template=template_body,
                parameters=formatted_params,
            )
        ),
    )

    result = deployment_poller.result()

    return {
        "deployment_name": result.name,
        "provisioning_state": result.properties.provisioning_state,
        "outputs": result.properties.outputs,
    }


# ============================================================================
# SECTION F: RESILIENCE PATTERNS
# ============================================================================


def demonstrate_retry_with_exponential_backoff() -> None:
    """Retry with exponential backoff using azure-core built-in retry policy.

    WHEN TO USE: All Azure SDK calls include automatic retry by default.
    Customize retry policy for specific SLA requirements or transient
    failure patterns.

    EXAM TIP: Azure SDK clients automatically retry on HTTP 408, 429, 500,
    502, 503, 504. The default policy uses exponential backoff with jitter.
    For AZ-305, understand that retry is a fundamental reliability pattern
    alongside circuit breaker, bulkhead, and timeout.
    """
    from azure.identity import DefaultAzureCredential
    from azure.storage.blob import BlobServiceClient
    from azure.core.pipeline.policies import RetryPolicy

    credential = DefaultAzureCredential()
    account_url = os.environ["AZURE_STORAGE_ACCOUNT_URL"]

    # Custom retry configuration
    client = BlobServiceClient(
        account_url,
        credential=credential,
        retry_total=5,            # Maximum retry attempts
        retry_backoff_factor=0.8, # Base delay multiplier (seconds)
        retry_backoff_max=60,     # Maximum delay between retries (seconds)
        retry_mode="exponential", # exponential or fixed
        # EXAM TIP: Connection timeout and read timeout should be tuned
        # based on your SLA. Aggressive timeouts improve failover speed
        # but may cause false positives under load.
        connection_timeout=10,
        read_timeout=30,
    )

    return client


def demonstrate_circuit_breaker_with_tenacity() -> None:
    """Circuit breaker pattern using tenacity library.

    WHEN TO USE: Protect upstream services from cascading failures. When a
    dependency is failing, stop calling it temporarily to allow recovery.

    EXAM TIP: Azure SDK retry handles transient failures. Circuit breaker
    handles sustained failures. Combine both: SDK retry for individual
    requests, circuit breaker to stop calling a degraded service.
    For AZ-305, this maps to the Reliability pillar -- graceful degradation.

    ALTERNATIVE: Azure API Management has built-in circuit breaker policy.
    Azure Container Apps has Dapr resiliency policies.
    """
    import tenacity

    # Circuit breaker: stop retrying after 5 consecutive failures,
    # wait 30 seconds before trying again (half-open state)
    @tenacity.retry(
        stop=tenacity.stop_after_attempt(5),
        wait=tenacity.wait_exponential(multiplier=1, min=2, max=30),
        retry=tenacity.retry_if_exception_type((ConnectionError, TimeoutError)),
        before_sleep=lambda retry_state: logging.warning(
            "Retry attempt %d after %s",
            retry_state.attempt_number,
            retry_state.outcome.exception() if retry_state.outcome else "unknown",
        ),
        reraise=True,
    )
    def call_external_service(endpoint: str) -> dict[str, Any]:
        """Call an external service with circuit breaker protection."""
        import urllib.request
        with urllib.request.urlopen(endpoint, timeout=10) as response:
            return json.loads(response.read())

    return call_external_service


def demonstrate_cosmos_preferred_regions() -> None:
    """Cosmos DB multi-region failover with preferred regions.

    WHEN TO USE: Global applications requiring low-latency reads from the
    nearest region with automatic failover during regional outages.

    EXAM TIP: Cosmos DB multi-region writes enable active-active globally.
    Multi-region reads with single-region write is cheaper but adds write
    latency for non-primary regions. AZ-305 tests on choosing between
    these configurations based on consistency, cost, and latency requirements.
    """
    from azure.identity import DefaultAzureCredential
    from azure.cosmos import CosmosClient

    credential = DefaultAzureCredential()
    endpoint = os.environ["COSMOS_ENDPOINT"]

    # Configure preferred regions for read failover order
    # EXAM TIP: Order matters -- SDK tries regions in list order.
    # Place the nearest region first for lowest latency.
    client = CosmosClient(
        endpoint,
        credential=credential,
        preferred_locations=[
            "East US",       # Primary (nearest to app)
            "West US",       # Secondary (same geography)
            "North Europe",  # Tertiary (cross-geography DR)
        ],
        # Consistency level per-request override
        # EXAM TIP: Cosmos DB consistency levels (strongest to weakest):
        # Strong > Bounded Staleness > Session > Consistent Prefix > Eventual
        # Session is the default and recommended for most applications.
        consistency_level="Session",
        # Enable endpoint discovery for automatic region failover
        enable_endpoint_discovery=True,
    )

    return client


def demonstrate_connection_pooling_sql() -> None:
    """SQL connection pooling for high-throughput applications.

    WHEN TO USE: Any application making frequent SQL queries. Connection
    pooling reuses established connections to avoid TCP handshake and
    authentication overhead per query.

    EXAM TIP: Azure SQL supports up to 30,000 concurrent connections
    (Business Critical tier). Connection pooling is essential to stay
    within limits. For serverless Azure Functions, use connection pooling
    at the host level (static/singleton clients).
    """
    import pyodbc

    # Connection pooling is enabled by default in pyodbc via ODBC driver
    # For production, set pool size and timeout at the driver level
    connection_string = (
        f"DRIVER={{ODBC Driver 18 for SQL Server}};"
        f"SERVER={os.environ['SQL_SERVER']}.database.windows.net;"
        f"DATABASE={os.environ['SQL_DATABASE']};"
        f"Encrypt=yes;"
        f"Connection Timeout=30;"
    )

    # Enable connection pooling (default in ODBC)
    pyodbc.pooling = True

    # For async frameworks (FastAPI, etc.), use aioodbc or asyncpg
    # EXAM TIP: Azure SQL Hyperscale supports up to 100 TB and
    # near-instant database snapshots. Recommend Hyperscale for
    # applications expecting significant data growth.

    return connection_string


# ============================================================================
# MAIN -- Demonstrate usage patterns (not meant for production execution)
# ============================================================================

if __name__ == "__main__":
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
    )

    print("=" * 70)
    print("AZ-305 Python Azure SDK Reference Examples")
    print("These are teaching examples for code review -- not a runnable script.")
    print("Each function demonstrates a specific Azure SDK pattern with")
    print("exam tips and architectural guidance.")
    print("=" * 70)
    print()
    print("Sections:")
    print("  A: Identity and Authentication")
    print("  B: Resource Management Patterns")
    print("  C: Data Operations (SQL, Cosmos DB, Blob, Service Bus, Event Grid)")
    print("  D: Monitoring and Observability (OpenTelemetry, Log Analytics, Alerts)")
    print("  E: Infrastructure as Code (Bicep/ARM deployment, What-If)")
    print("  F: Resilience Patterns (Retry, Circuit Breaker, Connection Pooling)")
    print()
    print("Reference: https://learn.microsoft.com/azure/developer/python/sdk/azure-sdk-overview")
