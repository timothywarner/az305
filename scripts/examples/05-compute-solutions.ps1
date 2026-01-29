#requires -Modules Az.Compute, Az.Aks, Az.Functions, Az.Batch

<#
.TITLE
    AZ-305 Domain 4: Compute and Application Architecture Solutions
.DOMAIN
    Domain 4 - Design Infrastructure Solutions (30-35%)
.DESCRIPTION
    Teaching examples covering VMs with proximity placement groups and availability
    zones, VMSS with autoscale, AKS clusters, Azure Container Apps, Azure Functions
    hosting plans, and Azure Batch. Code-review examples for AZ-305 classroom use.
.AUTHOR
    Tim Warner
.DATE
    January 2026
.NOTES
    Not intended for direct execution. Illustrates correct syntax and
    architectural decision-making for AZ-305 exam preparation.
#>

$subscriptionId = "00000000-0000-0000-0000-000000000000"
$resourceGroup  = "az305-rg"
$location       = "eastus"
$prefix         = "az305"

# ============================================================================
# SECTION 1: VM with Proximity Placement Groups and Availability Zones
# ============================================================================

# EXAM TIP: Proximity Placement Groups (PPGs) co-locate VMs in the SAME
# datacenter for ultra-low latency (<2ms). Used for HPC, SAP HANA, and
# tightly-coupled workloads. PPGs REDUCE availability (single datacenter)
# but INCREASE performance. This is a classic exam trade-off question.

# WHEN TO USE:
#   PPG                 -> Low-latency requirement between VMs (<2ms), HPC, SAP
#   Availability Zones  -> High availability (99.99% SLA), tolerant of ~1-2ms zone latency
#   Both (PPG + Zone)   -> Pin to a single zone for low latency WITH zone awareness
#   Neither             -> Single VMs in dev/test

# Create a proximity placement group
$ppgParams = @{
    ResourceGroupName = $resourceGroup
    Name              = "${prefix}-ppg"
    Location          = $location
    ProximityPlacementGroupType = "Standard"
    Zone              = "1"   # Optionally pin to a specific zone
}
$ppg = New-AzProximityPlacementGroup @ppgParams

# Create VMs in the proximity placement group for low-latency communication
$vmCredential = Get-Credential -Message "Enter VM admin credentials"

$vmConfig = New-AzVMConfig `
    -VMName "${prefix}-vm-hpc-01" `
    -VMSize "Standard_D8s_v5" `
    -ProximityPlacementGroupId $ppg.Id `
    -Zone "1"

$vmConfig = Set-AzVMOperatingSystem `
    -VM $vmConfig `
    -Windows `
    -ComputerName "hpc01" `
    -Credential $vmCredential

$vmConfig = Set-AzVMSourceImage `
    -VM $vmConfig `
    -PublisherName "MicrosoftWindowsServer" `
    -Offer "WindowsServer" `
    -Skus "2022-datacenter-g2" `
    -Version "latest"

$vmConfig = Set-AzVMOSDisk `
    -VM $vmConfig `
    -CreateOption "FromImage" `
    -StorageAccountType "Premium_LRS"  # Premium SSD for production

# Assign a user-assigned managed identity (Zero Trust -- no passwords for service auth)
$vmConfig = Set-AzVMIdentity `
    -VM $vmConfig `
    -IdentityType "UserAssigned" `
    -IdentityId "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${prefix}-vm-identity"

New-AzVM -ResourceGroupName $resourceGroup -Location $location -VM $vmConfig

# ============================================================================
# SECTION 2: VMSS with Autoscale Rules
# ============================================================================

# EXAM TIP: Virtual Machine Scale Sets (VMSS) provide auto-scaling for VM workloads.
# The exam tests: scale-out/scale-in rules, metrics, instance counts, and the
# difference between VMSS Uniform (legacy) and VMSS Flexible (modern, recommended).
# VMSS Flexible supports: mixed VM sizes, availability zones, and individual VM control.

# WHEN TO USE:
#   VMSS Flexible   -> Production auto-scaling, mixed sizes, zone redundancy (PREFERRED)
#   VMSS Uniform    -> Legacy, identical instances, rolling upgrades
#   App Service     -> Web apps (PaaS, simpler than VMSS)
#   Container Apps  -> Containerized apps (serverless scaling, HTTP-based)

$vmssParams = @{
    ResourceGroupName  = $resourceGroup
    VMScaleSetName     = "${prefix}-vmss"
    Location           = $location
    OrchestrationMode  = "Flexible"  # Modern orchestration mode
    SkuName            = "Standard_D4s_v5"
    SkuCapacity        = 2           # Initial instance count
    Zone               = @("1", "2", "3")  # Spread across all zones for 99.99% SLA
    ImageReferencePublisher = "Canonical"
    ImageReferenceOffer     = "0001-com-ubuntu-server-jammy"
    ImageReferenceSku       = "22_04-lts-gen2"
    ImageReferenceVersion   = "latest"
    UpgradePolicyMode       = "Automatic"  # Auto-apply image updates
}
$vmss = New-AzVmss @vmssParams

# Configure autoscale rules: scale OUT on high CPU, scale IN on low CPU
# EXAM TIP: Always configure BOTH scale-out and scale-in rules.
# Missing scale-in rules = VMs never removed = cost waste.
# Use different thresholds (e.g., out at 75%, in at 25%) to avoid flapping.

$scaleOutRule = New-AzAutoscaleRule `
    -MetricName "Percentage CPU" `
    -MetricResourceId $vmss.Id `
    -TimeGrain 00:01:00 `
    -Statistic "Average" `
    -TimeWindow 00:05:00 `
    -Operator "GreaterThan" `
    -Threshold 75 `
    -ScaleActionDirection "Increase" `
    -ScaleActionScaleType "ChangeCount" `
    -ScaleActionValue 2 `
    -ScaleActionCooldown 00:05:00  # Wait 5 min before next scale action

$scaleInRule = New-AzAutoscaleRule `
    -MetricName "Percentage CPU" `
    -MetricResourceId $vmss.Id `
    -TimeGrain 00:01:00 `
    -Statistic "Average" `
    -TimeWindow 00:10:00 `   # Longer window for scale-in (more conservative)
    -Operator "LessThan" `
    -Threshold 25 `
    -ScaleActionDirection "Decrease" `
    -ScaleActionScaleType "ChangeCount" `
    -ScaleActionValue 1 `
    -ScaleActionCooldown 00:10:00  # Longer cooldown to prevent flapping

$autoscaleProfile = New-AzAutoscaleProfile `
    -Name "DefaultProfile" `
    -DefaultCapacity 2 `
    -MaximumCapacity 10 `
    -MinimumCapacity 2 `
    -Rule $scaleOutRule, $scaleInRule

Add-AzAutoscaleSetting `
    -ResourceGroupName $resourceGroup `
    -Name "${prefix}-vmss-autoscale" `
    -TargetResourceUri $vmss.Id `
    -AutoscaleProfile $autoscaleProfile `
    -Notification @(
        New-AzAutoscaleNotification -EmailToSubscriptionAdministrator
    )

# ============================================================================
# SECTION 3: AKS Cluster with Azure CNI, RBAC, Managed Identity
# ============================================================================

# EXAM TIP: AKS is the managed Kubernetes service. Key exam topics:
# - Networking: kubenet vs Azure CNI (CNI = pods get VNet IPs, needed for Windows/policies)
# - Identity: Managed identity (preferred) vs service principal
# - RBAC: Kubernetes RBAC + Entra ID integration for unified access control
# - Node pools: System (control plane) + User (workloads), separate for isolation

# WHEN TO USE AKS vs alternatives:
#   AKS             -> Complex microservices, need Kubernetes features (service mesh,
#                      custom operators, Helm charts), team has K8s expertise
#   Container Apps  -> Simpler microservices, HTTP APIs, event-driven, NO K8s expertise needed
#   App Service     -> Traditional web apps, simple deployments, smallest team
#   Azure Functions -> Event-driven, short-lived compute, pay-per-execution

$aksParams = @{
    ResourceGroupName    = $resourceGroup
    Name                 = "${prefix}-aks"
    Location             = $location
    KubernetesVersion    = "1.30"
    NodeCount            = 3
    NodeVmSize           = "Standard_D4s_v5"
    NetworkPlugin        = "azure"         # Azure CNI: pods get VNet IPs
    NetworkPolicy        = "azure"         # Azure Network Policy for pod-level NSGs
    EnableRBAC           = $true           # Kubernetes RBAC
    EnableAzureRBAC      = $true           # Entra ID RBAC integration
    EnableManagedIdentity = $true          # Managed identity (not service principal)
    NodePoolName         = "system"        # System node pool for control plane pods
    AvailabilityZone     = @(1, 2, 3)     # Zone-redundant nodes
    EnableAutoScaling    = $true
    MinCount             = 3
    MaxCount             = 10
}
$aks = New-AzAksCluster @aksParams

# Add a user node pool for application workloads (isolation from system pods)
$userPoolParams = @{
    ResourceGroupName  = $resourceGroup
    ClusterName        = "${prefix}-aks"
    Name               = "apppool"
    VmSize             = "Standard_D8s_v5"
    EnableAutoScaling  = $true
    MinCount           = 2
    MaxCount           = 20
    AvailabilityZone   = @(1, 2, 3)
    Mode               = "User"
    OsType             = "Linux"
    MaxPodCount        = 110             # Azure CNI default, increase for dense packing
}
New-AzAksNodePool @userPoolParams

# EXAM TIP: Separate system and user node pools. System pools run critical pods
# (CoreDNS, kube-proxy). User pools run your application workloads. This prevents
# resource contention and allows independent scaling.

# ============================================================================
# SECTION 4: Azure Container Apps (Consumption, Scale-to-Zero)
# ============================================================================

# EXAM TIP: Azure Container Apps is the SERVERLESS container platform. It runs
# on top of Kubernetes (KEDA + Envoy + Dapr) but abstracts away all cluster mgmt.
# Key features: HTTP auto-scale, scale-to-zero, Dapr integration, revision traffic splitting.

# WHEN TO USE Container Apps:
#   - Microservices WITHOUT Kubernetes expertise
#   - HTTP APIs with variable traffic (scale to zero = pay nothing at idle)
#   - Event-driven containers (KEDA scalers for queues, Event Hubs, etc.)
#   - Background processing jobs
# When NOT to use: Need full Kubernetes API access, custom operators, service mesh control

# Container Apps require the Az.App module or CLI -- using CLI-style via PowerShell
# for clarity since the Az.App module is relatively new

# Create a Container Apps environment (shared infrastructure for multiple apps)
# EXAM TIP: The environment is the isolation boundary. Apps in the same environment
# share a VNet, Log Analytics, and can communicate via internal DNS.

# Note: Container Apps management is best done via Azure CLI or Bicep.
# Conceptual PowerShell equivalent shown here for teaching purposes.

# az containerapp env create `
#     --name "${prefix}-cae" `
#     --resource-group "$resourceGroup" `
#     --location "$location" `
#     --logs-workspace-id "<law-customer-id>" `
#     --logs-workspace-key "<law-key>" `
#     --enable-workload-profiles true

# Deploy a container app with HTTP scaling
# az containerapp create `
#     --name "${prefix}-api" `
#     --resource-group "$resourceGroup" `
#     --environment "${prefix}-cae" `
#     --image "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest" `
#     --target-port 80 `
#     --ingress external `
#     --min-replicas 0 `     # Scale to zero when no traffic
#     --max-replicas 10 `
#     --cpu 0.5 `
#     --memory 1.0Gi `
#     --scale-rule-name "http-scaling" `
#     --scale-rule-type "http" `
#     --scale-rule-http-concurrency 100  # Scale out when >100 concurrent requests

# EXAM TIP: Container Apps supports TWO plan types:
#   Consumption    -> Serverless, pay-per-use, scale-to-zero, limited resources
#   Workload Profile -> Dedicated compute, GPU support, larger resource limits
# Choose Consumption for most scenarios; Workload Profile for GPU/memory-intensive work.

# ============================================================================
# SECTION 5: Azure Functions Hosting Plan Comparison
# ============================================================================

# EXAM TIP: Azure Functions has THREE hosting plans. This is a TOP exam topic:
#
# +---------------+------------+-----------+----------+------------------------+
# | Feature       | Consumption| Premium   | Dedicated| Flex Consumption       |
# +---------------+------------+-----------+----------+------------------------+
# | Scale-to-zero | Yes        | No (1 min)| No       | Yes                    |
# | Max timeout   | 5/10 min   | Unlimited | Unlimited| Unlimited              |
# | VNet access   | No         | Yes       | Yes      | Yes                    |
# | Min instances | 0          | 1+        | 1+       | 0                      |
# | Max scale     | 200        | 100       | 10-30    | 1000                   |
# | Cold start    | Yes        | Minimal   | No       | Configurable           |
# | Cost          | Lowest     | Medium    | Highest  | Pay-per-use + baseline |
# +---------------+------------+-----------+----------+------------------------+

# WHEN TO USE:
#   Consumption      -> Sporadic event-driven workloads, lowest cost, OK with cold starts
#   Premium (EP)     -> VNet integration needed, long-running, no cold starts, moderate scale
#   Dedicated (ASP)  -> Already paying for App Service Plan, predictable cost, always-on
#   Flex Consumption -> New! Best of both: scale-to-zero + VNet + fast scale + no cold start

# --- Consumption Plan Function App ---
$consumptionParams = @{
    ResourceGroupName = $resourceGroup
    Name              = "${prefix}-func-consumption"
    Location          = $location
    StorageAccountName = "${prefix}storage"
    Runtime           = "dotnet-isolated"
    RuntimeVersion    = "8"
    FunctionsVersion  = "4"
    OSType            = "Linux"
}
New-AzFunctionApp @consumptionParams

# --- Premium Plan Function App (VNet-integrated, no cold starts) ---
$premiumPlanParams = @{
    ResourceGroupName = $resourceGroup
    Name              = "${prefix}-func-premium-plan"
    Location          = $location
    Sku               = "EP1"  # Elastic Premium: 1 vCPU, 3.5 GB RAM
    WorkerType        = "Linux"
}
$premiumPlan = New-AzFunctionAppPlan @premiumPlanParams

$premiumFuncParams = @{
    ResourceGroupName  = $resourceGroup
    Name               = "${prefix}-func-premium"
    PlanName           = "${prefix}-func-premium-plan"
    StorageAccountName = "${prefix}storage"
    Runtime            = "dotnet-isolated"
    RuntimeVersion     = "8"
    FunctionsVersion   = "4"
    OSType             = "Linux"
}
New-AzFunctionApp @premiumFuncParams

# EXAM TIP: Premium plan supports VNet integration (outbound) and Private Endpoints
# (inbound). This is REQUIRED for functions that must access private resources
# (SQL with Private Endpoint, Storage with firewall, internal APIs).

# ============================================================================
# SECTION 6: Azure Batch Pool Creation
# ============================================================================

# EXAM TIP: Azure Batch is for LARGE-SCALE PARALLEL and HPC workloads.
# Think: rendering, simulations, genetic sequencing, financial modeling.
# Batch manages VM pools, job scheduling, and auto-scaling for you.

# WHEN TO USE:
#   Azure Batch   -> Embarrassingly parallel jobs, HPC, rendering, 1000s of VMs
#   VMSS          -> Long-running services with auto-scale (web servers)
#   AKS           -> Containerized batch jobs with Kubernetes orchestration
#   Azure Functions -> Lightweight event-driven processing (not HPC-scale)

$batchAccountParams = @{
    ResourceGroupName = $resourceGroup
    Name              = "${prefix}batch"
    Location          = $location
}
$batchAccount = New-AzBatchAccount @batchAccountParams

# Create a pool of compute nodes for batch processing
$poolParams = @{
    Id                = "render-pool"
    VirtualMachineSize = "Standard_D16s_v5"
    TargetDedicatedComputeNodes = 4    # Always-on nodes (predictable cost)
    TargetLowPriorityComputeNodes = 20 # Spot/low-priority (up to 80% cheaper, can be evicted)
}

# EXAM TIP: Low-priority (Spot) nodes in Batch can save up to 80% but may be evicted.
# Use for: fault-tolerant workloads that can checkpoint and retry.
# NOT for: time-sensitive jobs that cannot tolerate interruption.

# Auto-scale formula: scale based on pending tasks
$autoScaleFormula = @"
startingNumberOfVMs = 2;
maxNumberOfVMs = 50;
pendingTaskSamplePercent = `$PendingTasks.GetSamplePercent(180 * TimeInterval_Second);
pendingTaskSamples = pendingTaskSamplePercent < 70 ? startingNumberOfVMs : avg(`$PendingTasks.GetSample(180 * TimeInterval_Second));
`$TargetDedicatedNodes = min(maxNumberOfVMs, pendingTaskSamples);
`$NodeDeallocationOption = taskcompletion;
"@

# ============================================================================
# SECTION 7: Compute Decision Tree
# ============================================================================

# EXAM TIP: The AZ-305 exam FREQUENTLY asks you to choose the right compute service.
# Use this decision tree:
#
#   Is it a web application?
#     |-- Simple web app, no containers -> App Service
#     |-- Containerized web app, no K8s expertise -> Container Apps
#     |-- Complex microservices, need K8s API -> AKS
#
#   Is it event-driven?
#     |-- Short-lived (<10 min), sporadic -> Functions (Consumption)
#     |-- Needs VNet, long-running -> Functions (Premium) or Container Apps
#     |-- Queue/Event Hub processing -> Functions or Container Apps (KEDA)
#
#   Is it a batch/HPC workload?
#     |-- 1000s of parallel tasks -> Azure Batch
#     |-- GPU rendering -> Azure Batch with GPU VMs
#     |-- Hadoop/Spark -> HDInsight or Databricks
#
#   Is it a legacy app (lift and shift)?
#     |-- Windows services, registry dependencies -> Azure VM
#     |-- SQL Server with CLR, linked servers -> SQL Managed Instance
#     |-- Full OS control needed -> Azure VM
#
#   Need GPU for AI/ML?
#     |-- Training -> Azure ML Compute or AKS with GPU nodes
#     |-- Inference API -> Container Apps or AKS with GPU
#     |-- Pre-built AI -> Azure OpenAI Service (no custom GPU needed)
#
# COST COMPARISON (approximate monthly for comparable workload):
#   Functions Consumption:  $0-50     (pay per execution, scale to zero)
#   Container Apps:         $50-200   (pay per vCPU-second, scale to zero)
#   App Service (B1):       $55       (always on, single instance)
#   AKS (3x D4s_v5):       $400+     (always on, plus management overhead)
#   VM (D4s_v5):            $140      (always on, full OS management)
#   Batch (Spot D16s_v5):   $0.05/hr  (per node, evictable)
