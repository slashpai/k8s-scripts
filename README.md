# k8s-scripts

Kubernetes cluster related scripts

## Create `n` number of namespaces and `m` number of secrets in each namespace

[create_k8s_resources.sh](create_k8s_resources.sh)

```bash
[╰─ ./create_k8s_resources.sh --help                                                                                                                                                                                ─╯
Usage: ./create_k8s_resources.sh [namespace_count] [secrets_per_namespace]
       ./create_k8s_resources.sh cleanup

Arguments:
  namespace_count: Number of namespaces to create (default: 100)
  secrets_per_namespace: Number of secrets to create per namespace (default: 5)
  cleanup: Delete all created namespaces and secrets

Examples:
  ./create_k8s_resources.sh                    # Create 100 namespaces with 5 secrets each
  ./create_k8s_resources.sh 50                 # Create 50 namespaces with 5 secrets each
  ./create_k8s_resources.sh 50 10              # Create 50 namespaces with 10 secrets each
  ./create_k8s_resources.sh cleanup            # Delete all created resources

Options:
  --help, -h: Show this help message]
  ```
