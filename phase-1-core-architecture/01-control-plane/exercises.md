# Control Plane Exercises

## Exercise 1: Watch API Server
```bash
kubectl get pods -n k8s-learning -v=8
```

**Result**: Observed REST API calls, authentication, 10ms response time

## Exercise 2: Controller Reconciliation
```bash
kubectl delete pod -l app=demo --force
```

**Result**: New pod created within 2-3 seconds by ReplicaSet controller
