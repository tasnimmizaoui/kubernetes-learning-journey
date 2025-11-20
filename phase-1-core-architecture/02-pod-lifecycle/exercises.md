# Pod Lifecycle Exercises

## Exercise 1: Init Container Sequence
```bash
kubectl apply -f manifests/lifecycle-demo.yaml
kubectl get pods -n k8s-learning -w
```

**Observed**:
```
lifecycle-demo   0/2     Init:0/2         3s
lifecycle-demo   0/2     Init:1/2         6s
lifecycle-demo   0/2     PodInitializing  9s
lifecycle-demo   2/2     Running          13s
```

Init containers ran sequentially: init-1 (3s) → init-2 (2s) → main containers

## Exercise 2: Lifecycle Hooks
```bash
kubectl exec lifecycle-demo -c main-app -- cat /usr/share/nginx/html/startup.html
kubectl delete pod lifecycle-demo
```

**Result**: 
- postStart created file with timestamp
- preStop caused 5-second delay before termination

## Exercise 3: Restart Policies
```bash
kubectl apply -f manifests/restart-policy-demo.yaml
kubectl get pods -w
```

**Result**: Container crashed, automatically restarted (restartPolicy: Always)
