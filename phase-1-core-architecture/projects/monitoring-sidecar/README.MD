# Monitoring Sidecar Pattern - Documentation

## Overview
This project demonstrates the **Sidecar Pattern** in Kubernetes, where auxiliary containers run alongside the main application container to provide additional functionality like log processing and metrics collection.

## Architecture
┌─────────────────────────────────────────────────────────────┐
│ Pod 
│ ┌─────────────┐ ┌─────────────────┐ ┌─────────────────┐     │
│ │ 
│ │ Main App         Log Processor  │ │ Metrics Exporter│     │
│ │ Container        Sidecar        │ │ Sidecar         │     │
│ │              
│ └─────────────┘ └─────────────────┘ └─────────────────┘     │
│
│ ▼ ▼ ▼ 
│ /var/log/app/ /var/log/processed/ 
|   --> Console Output                                        │
│ application.log alerts.log, warnings.log                    │
│ info.log, metrics.log                                       │
└─────────────────────────────────────────────────────────────┘
Key Concepts
------------

### Sidecar Pattern

*   **Definition**: Auxiliary containers that extend/enhance the main application container
    
*   **Benefits**: Separation of concerns, reusable components, modular architecture
    
*   **Use Cases**: Log processing, metrics collection, security proxies, configuration reloaders
    

### Log Processing Flow

1.  **Main App** → Writes logs to /var/log/app/application.log
    
2.  **Log Processor** → Reads, parses, and categorizes logs
    
3.  **Metrics Exporter** → Analyzes log patterns and reports metrics
    

### Volume Sharing

*   **emptyDir**: Shared volume between all containers in the pod
    
*   **Lifecycle**: Tied to pod lifecycle, data persists across container restarts
    
*   **Usage**: Main app writes logs, sidecars read/process them
    

### Init Containers

*   **Purpose**: Run setup tasks before main containers start
    
*   **In this project**: Creates necessary log directories
    
*   **Guarantee**: Runs to completion before app containers start
## Components

### 1. Namespace
- **`monitoring-demo`**: Isolates all project resources

### 2. ConfigMap
- **`log-processor-config`**: Contains the log processing script

### 3. Deployment
- **`app-with-monitoring`**: Main deployment with 3 containers
  - **Main App**: Generates simulated log data
  - **Log Processor**: Processes and categorizes logs
  - **Metrics Exporter**: Analyzes and reports metrics

### 4. Service
- **`monitored-app-service`**: ClusterIP service for the application

## Debugging & Exploration Commands

### Basic Cluster Operations

```bash
# Apply the configuration
kubectl apply -f monitoring-sidecar.yaml

# Delete all resources
kubectl delete -f monitoring-sidecar.yaml

# Check all resources in namespace
kubectl get all -n monitoring-demo

# Get pods with node information
kubectl get pods -n monitoring-demo -o wide

# Describe a specific pod
kubectl describe pod <pod-name> -n monitoring-demo

# Get pod with labels
kubectl get pods -n monitoring-demo --show-labels

#######################################################################"
# Get main application logs
kubectl logs -n monitoring-demo -l app=monitored-app -c app

# Get log processor sidecar logs
kubectl logs -n monitoring-demo -l app=monitored-app -c log-processor

# Get metrics exporter logs
kubectl logs -n monitoring-demo -l app=monitored-app -c metrics-exporter

# Follow logs in real-time
kubectl logs -n monitoring-demo -l app=monitored-app -c app --follow

# Get logs from a specific pod
POD=$(kubectl get pod -n monitoring-demo -l app=monitored-app -o jsonpath='{.items[0].metadata.name}')
kubectl logs $POD -n monitoring-demo -c app