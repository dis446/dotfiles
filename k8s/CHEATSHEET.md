# Kubectl Cheatsheet

> Quick reference for daily `kubectl` operations. Context: personal cluster
> (k3s/Kubernetes) running in a home-lab style setup. Commands assume
> a working `~/.kube/config`.

---

## Context & Config

```bash
# List contexts
kubectl config get-contexts

# Switch context
kubectl config use-context <name>

# Set default namespace for current context
kubectl config set-context --current --namespace=<ns>

# View current context + cluster info
kubectl config current-context
kubectl cluster-info

# Dump full config
kubectl config view
```

---

## Pods

```bash
# List pods (with node & IP)
kubectl get pods -o wide

# Watch pod state
kubectl get pods -w

# Describe a pod (events, status, conditions)
kubectl describe pod <name>

# Pod logs
kubectl logs <name>                  # single container
kubectl logs <name> -c <container>   # specific container
kubectl logs -f <name>               # follow
kubectl logs --tail=50 <name>        # last N lines
kubectl logs --since=5m <name>       # recent window

# Exec into a running pod
kubectl exec -it <name> -- /bin/sh
kubectl exec -it <name> -c <container> -- /bin/bash

# Port-forward (local → pod)
kubectl port-forward pod/<name> 8080:80
kubectl port-forward pod/<name> 8080:80 3000:3000  # multiple

# Delete a pod (ReplicaSet recreates it; useful for restart)
kubectl delete pod <name>
```

---

## Deployments

```bash
# List
kubectl get deployments
kubectl get deployments -o wide

# Create
kubectl create deployment <name> --image=<image>

# Scale
kubectl scale deployment/<name> --replicas=5
kubectl scale deployment/<name> --replicas=0   # "stop" without deleting

# Autoscale (requires metrics-server)
kubectl autoscale deployment/<name> --min=2 --max=10 --cpu-percent=80

# Rollout management
kubectl rollout status deployment/<name>
kubectl rollout history deployment/<name>
kubectl rollout undo deployment/<name>            # previous
kubectl rollout undo deployment/<name> --to-revision=3

# Restart (no-downtime re-create all pods)
kubectl rollout restart deployment/<name>

# Edit live YAML
kubectl edit deployment/<name>

# Expose deployment as a service
kubectl expose deployment/<name> --port=80 --target-port=8080
```

---

## Services

```bash
# List
kubectl get services
kubectl get svc -o wide
kubectl get endpoints                         # actual pod IPs behind each service

# Types: ClusterIP | NodePort | LoadBalancer | ExternalName
kubectl get svc <name> -o yaml               # full spec
kubectl describe svc <name>

# Port-forward to a service (not just pod)
kubectl port-forward svc/<name> 8080:80

# Create
kubectl create service clusterip <name> --tcp=80:8080
kubectl create service nodeport <name> --tcp=80:8080
```

---

## Ingress

```bash
# List
kubectl get ingress
kubectl get ingress -A

# Describe (shows host, paths, backend service:port, TLS)
kubectl describe ingress <name>

# Annotations for common ingress controllers
#   nginx:   kubernetes.io/ingress.class: nginx
#   traefik: traefik.ingress.kubernetes.io/router.entrypoints: websecure
#   cert:    cert-manager.io/cluster-issuer: letsencrypt-prod
```

---

## ConfigMaps & Secrets

```bash
# ConfigMaps
kubectl get configmaps
kubectl create configmap <name> --from-literal=key=val
kubectl create configmap <name> --from-file=config.yaml
kubectl create configmap <name> --from-env-file=.env

# Secrets
kubectl get secrets
kubectl create secret generic <name> --from-literal=key=val
kubectl create secret generic <name> --from-file=id_rsa
kubectl create secret tls <name> --cert=tls.crt --key=tls.key

# View (get shows only keys; describe shows size)
kubectl get secret <name> -o yaml            # base64-encoded
kubectl get secret <name> -o jsonpath='{.data.\*}'
kubectl get secret <name> -o go-template='{{.data.key | base64decode}}'

# Edit (decodes base64 values for you)
kubectl edit secret <name>
```

---

## Debugging & Diagnostics

```bash
# Describe — best first step when something is stuck
kubectl describe pod/<name>
kubectl describe node/<name>       # resource pressure, taints, conditions

# Events sorted by time
kubectl get events --sort-by='.lastTimestamp'
kubectl get events -w                      # watch live
kubectl get events --field-selector type=Warning

# Resource usage (requires metrics-server)
kubectl top pods
kubectl top nodes
kubectl top pods -n <ns>

# Temporary debug pod (ephemeral container, K8s v1.23+)
kubectl debug pod/<name> -it --image=nicolaka/netshoot

# Run ad-hoc pod for testing
kubectl run test --image=nicolaka/netshoot -it --rm -- /bin/bash
kubectl run test --image=curlimages/curl -it --rm -- sh

# Copy files out of a pod
kubectl cp <pod-name>:/path/to/file ./local-file
kubectl cp ./local-file <pod-name>:/path/to/dest   # into pod
```

---

## Nodes

```bash
# List
kubectl get nodes -o wide

# Labels
kubectl get nodes --show-labels
kubectl label node <name> <key>=<value>

# Cordon / Drain / Uncordon (maintenance)
kubectl cordon <node>           # mark unschedulable
kubectl drain <node> --ignore-daemonsets --delete-emptydir-data
kubectl uncordon <node>         # mark schedulable again

# Taints
kubectl taint nodes <name> key=value:NoSchedule
kubectl taint nodes <name> key=value:NoExecute-
```

---

## Namespaces

```bash
# List
kubectl get namespaces

# Switch namespace permanently (config)
kubectl config set-context --current --namespace=<ns>

# Short alias — list all resources in a namespace
kubectl get all -n <ns>
```

---

## Apply / Delete (Declarative)

```bash
# Apply a manifest (creates or updates)
kubectl apply -f deployment.yaml
kubectl apply -f ./manifests/
kubectl apply -f https://example.com/manifest.yaml

# Dry-run (validate before applying)
kubectl apply -f deployment.yaml --dry-run=client
kubectl apply -f deployment.yaml --dry-run=server

# Delete
kubectl delete -f deployment.yaml
kubectl delete -f ./manifests/
kubectl delete pod,service --all          # delete all in current ns

# Diff (changes that apply would make)
kubectl diff -f deployment.yaml
```

---

## Imperative Create (Quick)

```bash
# Run a pod (one-shot)
kubectl run nginx --image=nginx --restart=Never

# Create a CronJob
kubectl create cronjob <name> --image=<image> --schedule="*/5 * * * *" -- echo hello

# Create a Job
kubectl create job <name> --image=<image> -- echo hello
```

---

## Labels & Selectors

```bash
# Filter by label
kubectl get pods -l app=nginx
kubectl get pods -l 'app in (nginx,redis)'
kubectl get pods -l 'tier!=frontend'
kubectl get pods -l 'app=nginx,env=prod'   # AND

# Add/overwrite label
kubectl label pod <name> version=2.0

# Remove label (trailing dash)
kubectl label pod <name> version-

# Annotations (metadata, not selectable)
kubectl annotate pod <name> description="my pod"
kubectl annotate pod <name> description-
```

---

## JSONPath / Custom Columns

```bash
# Get specific fields
kubectl get pods -o jsonpath='{.items[*].metadata.name}'
kubectl get pods -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.podIP}{"\n"}{end}'

# Custom columns
kubectl get pods -o custom-columns=NAME:.metadata.name,IP:.status.podIP,NODE:.spec.nodeName
kubectl get nodes -o custom-columns=NAME:.metadata.name,TAINTS:.spec.taints

# Wide + labels combo
kubectl get pods -o wide -L app -L env    # adds label columns
```

---

## Wait & Conditions

```bash
# Block until condition is met
kubectl wait --for=condition=Ready pod/<name>
kubectl wait --for=condition=Available deployment/<name> --timeout=60s
kubectl wait --for=condition=ContainersReady pod/<name>

# Wait for deletion
kubectl wait --for=delete pod/<name> --timeout=30s

# Combined — rollout deploy and wait
kubectl rollout status deployment/<name> -w
```

---

## Resource Types (short names)

```
pod              po
service          svc
deployment       deploy
replicaset       rs
statefulset      sts
daemonset        ds
configmap        cm
secret           (no short alias)
namespace        ns
node             no
ingress          ing
endpoints        ep
persistentvolume         pv
persistentvolumeclaim    pvc
clusterrole              (no short alias)
clusterrolebinding       (no short alias)
serviceaccount   sa
cronjob          cj
job              (no short alias)
networkpolicy    netpol
```

---

## API Resources

```bash
# List all API resources + their short names
kubectl api-resources
kubectl api-resources --namespaced=true
kubectl api-resources --verbs=list,get

# Check API versions
kubectl api-versions

# Explain a resource field
kubectl explain pod
kubectl explain pod.spec.containers
kubectl explain deployment.spec.template.spec.containers.resources
```

---

## Aliases (put in `~/.bashrc`)

```bash
alias k='kubectl'
alias kg='k get'
alias kgp='k get pods'
alias kgd='k get deployments'
alias kgs='k get svc'
alias kgi='k get ingress'
alias kga='k get all'
alias kgn='k get nodes'
alias kdel='k delete'
alias ksys='k -n kube-system'
alias kall='k get pods --all-namespaces'
alias kdesc='k describe'
alias kpf='k port-forward'
alias kx='k exec -it'
alias kl='k logs'
alias klf='k logs -f'
alias kapply='k apply -f'

# Context-aware prompt helpers
alias kctx='k config current-context'
alias kns='k config view --minify -o jsonpath="{..namespace}"'
```

---

## One-liner Gems

```bash
# What broke recently?
k get events --sort-by='.lastTimestamp' | tail -20

# Find pods in CrashLoopBackOff
k get pods -A | grep -E 'CrashLoop|Error|ImagePull|Init:'

# Free memory on a node by evicting low-priority pods
k get pods --field-selector=status.phase=Running -o name | xargs k delete

# See image versions running across all namespaces
k get pods -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[*].image}{"\n"}{end}'

# Show pod-to-node mapping
k get pods -o wide --no-headers | awk '{print $1, $7}'

# Show resource requests/limits for all pods
k get pods -A -o custom-columns=NS:.metadata.namespace,POD:.metadata.name,CPU_REQ:.spec.containers[*].resources.requests.cpu,MEM_REQ:.spec.containers[*].resources.requests.memory,CPU_LIM:.spec.containers[*].resources.limits.cpu,MEM_LIM:.spec.containers[*].resources.limits.memory

# Delete all Evicted pods
k delete pods --field-selector=status.phase=Failed

# Which node has the most pods?
k get pods -o wide --no-headers | awk '{print $7}' | sort | uniq -c | sort -rn
```

---

## Helm (common companion)

```bash
helm list                                     # releases
helm list -a                                  # including uninstalled
helm repo update                              # refresh repos
helm search repo <name>                       # search repos
helm search hub <name>                        # search artifact hub

# Install / upgrade
helm install <release> <chart> -n <ns>
helm upgrade <release> <chart> -f values.yaml
helm upgrade --install <release> <chart> --atomic

# Rollback
helm rollback <release> <revision>
helm history <release>

# Render templates locally (debug)
helm template <release> <chart> -f values.yaml
helm lint <chart>
```

---

## `kubectl` Cheat: Bash Completion

```bash
# Enable kubectl bash completion (already in dotfiles? check)
source <(kubectl completion bash)
echo 'source <(kubectl completion bash)' >> ~/.bashrc
```

> **Pro tip:** Combine `kubectl` with `jq` / `yq` for advanced filtering
> beyond `jsonpath` — great for scripting.
