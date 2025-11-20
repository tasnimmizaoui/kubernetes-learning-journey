# kubectl Cheatsheet

## Pods
```bash
kubectl get pods -n <namespace> -w              # Watch pods
kubectl get pods -v=8                           # Verbose API calls
kubectl describe pod <name>                     # Detailed info
kubectl logs <pod> -c <container>               # Container logs
kubectl exec <pod> -c <container> -- <command>  # Execute command
```

## Debugging
```bash
kubectl get events -n <namespace> --watch
kubectl get pod <name> -o yaml
kubectl get pod <name> -o jsonpath='{.status.phase}'
```

## Init Containers
```bash
kubectl logs <pod> -c <init-container-name>
kubectl describe pod <pod> | grep -A 20 "Init Containers:"
```
