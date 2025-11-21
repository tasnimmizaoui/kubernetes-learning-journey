# Monitoring Sidecar Pattern - Documentation

## Overview
This project demonstrates the **Sidecar Pattern** in Kubernetes, where auxiliary containers run alongside the main application container to provide additional functionality like log processing and metrics collection.

## Key Concepts

### Sidecar Pattern

*   **Definition**: Auxiliary containers that extend/enhance the main application container
*   **Benefits**: Separation of concerns, reusable components, modular architecture
*   **Use Cases**: Log processing, metrics collection, security proxies, configuration reloaders

### Log Processing Flow

1.  **Main App** → Writes logs to `/var/log/app/application.log`
2.  **Log Processor** → Reads, parses, and categorizes logs
3.  **Metrics Exporter** → Analyzes log patterns and reports metrics

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
```

### Logs Inspection

```bash
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
```

### Interactive Debugging

```bash
# Execute into main app container
kubectl exec -it -n monitoring-demo -l app=monitored-app -c app -- /bin/sh

# Execute into log processor container
kubectl exec -it -n monitoring-demo -l app=monitored-app -c log-processor -- /bin/sh

# Check file structure in pod
kubectl exec -it -n monitoring-demo -l app=monitored-app -c app -- ls -la /var/log/

# View processed logs
kubectl exec -it -n monitoring-demo -l app=monitored-app -c log-processor -- cat /var/log/processed/alerts.log

# Check metrics file
kubectl exec -it -n monitoring-demo -l app=monitored-app -c metrics-exporter -- cat /var/log/processed/metrics.log
```

### Resource Monitoring

```bash
# Check resource usage
kubectl top pods -n monitoring-demo

# Check resource requests/limits
kubectl describe pod -n monitoring-demo -l app=monitored-app | grep -A 5 Resources

# Get detailed pod information
kubectl get pod -n monitoring-demo -l app=monitored-app -o yaml
```

### Service Discovery

```bash
# Check service endpoints
kubectl get endpoints -n monitoring-demo

# Describe service
kubectl describe service monitored-app-service -n monitoring-demo

# Test service connectivity (from within cluster)
kubectl run test -it --rm --image=busybox -n monitoring-demo -- wget -qO- http://monitored-app-service:80
```

## Common Issues & Troubleshooting

### Pod Not Starting
```bash
# Check pod events
kubectl describe pod <pod-name> -n monitoring-demo

# Check init container status
kubectl get pods -n monitoring-demo -o jsonpath='{.items[*].status.initContainerStatuses[*].name}'
```

### Container Crash
```bash
# Check container status
kubectl get pods -n monitoring-demo -o jsonpath='{.items[*].status.containerStatuses[*].name}'

# View previous container logs (if restarted)
kubectl logs -n monitoring-demo -l app=monitored-app -c app --previous
```

### Log File Issues
```bash
# Check if log files exist
kubectl exec -it -n monitoring-demo -l app=monitored-app -c app -- ls -la /var/log/app/

# Check disk space
kubectl exec -it -n monitoring-demo -l app=monitored-app -c app -- df -h
```

## Cleanup
```bash
# Delete namespace (deletes everything in it)
kubectl delete namespace monitoring-demo

# Or delete individual resources
kubectl delete deployment app-with-monitoring -n monitoring-demo
kubectl delete service monitored-app-service -n monitoring-demo
kubectl delete configmap log-processor-config -n monitoring-demo
```

## Best Practices Demonstrated

1. **Resource Limits**: All containers have CPU/Memory requests/limits
2. **Separation of Concerns**: Each container has a single responsibility
3. **Shared Volumes**: Efficient inter-container communication
4. **Init Containers**: Proper initialization sequence
5. **ConfigMaps**: Configuration separated from code
6. **Namespaces**: Resource isolation