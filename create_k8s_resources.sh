#!/bin/bash

# Script to create namespaces and secrets in Kubernetes cluster using kubectl
# Usage: ./create_k8s_resources.sh [namespace_count] [secrets_per_namespace]

set -e

# Configuration
NAMESPACE_COUNT=${1:-100}  # Default to 100 namespaces if not specified
SECRETS_PER_NAMESPACE=${2:-5}  # Default to 5 secrets per namespace if not specified
BASE_NAMESPACE_NAME="test-ns"
BASE_SECRET_NAME="secret"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to validate numeric arguments
validate_args() {
    if ! [[ "$NAMESPACE_COUNT" =~ ^[0-9]+$ ]] || [ "$NAMESPACE_COUNT" -le 0 ]; then
        log_error "Namespace count must be a positive integer"
        exit 1
    fi
    
    if ! [[ "$SECRETS_PER_NAMESPACE" =~ ^[0-9]+$ ]] || [ "$SECRETS_PER_NAMESPACE" -le 0 ]; then
        log_error "Secrets per namespace must be a positive integer"
        exit 1
    fi
}

# Function to check if kubectl is available
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check if we can connect to cluster
    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    
    log_info "Successfully connected to Kubernetes cluster"
}

# Function to create namespaces using kubectl
create_namespaces() {
    log_info "Creating $NAMESPACE_COUNT namespaces..."
    
    for i in $(seq 1 $NAMESPACE_COUNT); do
        namespace_name="${BASE_NAMESPACE_NAME}-$(printf "%03d" $i)"
        
        if kubectl get namespace "$namespace_name" &> /dev/null; then
            log_info "Namespace $namespace_name already exists, skipping..."
        else
            kubectl create namespace "$namespace_name"
            log_info "Created namespace: $namespace_name"
        fi
    done
}

# Function to create secrets using kubectl
create_secrets() {
    log_info "Creating $SECRETS_PER_NAMESPACE secrets per namespace..."
    
    for i in $(seq 1 $NAMESPACE_COUNT); do
        namespace_name="${BASE_NAMESPACE_NAME}-$(printf "%03d" $i)"
        
        # Skip if namespace doesn't exist
        if ! kubectl get namespace "$namespace_name" &> /dev/null; then
            continue
        fi
        
        for j in $(seq 1 $SECRETS_PER_NAMESPACE); do
            secret_name="${BASE_SECRET_NAME}-$(printf "%03d" $j)"
            
            # Generate random data for the secret
            username="user-$i-$j"
            password=$(openssl rand -base64 12 2>/dev/null || echo "password-$i-$j")
            
            # Create secret using kubectl
            kubectl create secret generic "$secret_name" \
                --from-literal=username="$username" \
                --from-literal=password="$password" \
                --namespace="$namespace_name" \
                --dry-run=client -o yaml | kubectl apply -f -
                
            if [ $? -eq 0 ]; then
                log_info "Created secret $secret_name in namespace $namespace_name"
            else
                log_error "Failed to create secret $secret_name in namespace $namespace_name"
            fi
        done
    done
}

# Function to verify created resources
verify_resources() {
    log_info "Verifying created resources..."
    
    # Count namespaces
    namespace_count=$(kubectl get namespaces --no-headers | grep "^${BASE_NAMESPACE_NAME}-" | wc -l)
    log_info "Found $namespace_count namespaces with prefix '$BASE_NAMESPACE_NAME-'"
    
    # Count secrets across all created namespaces
    total_secrets=0
    for i in $(seq 1 $NAMESPACE_COUNT); do
        namespace_name="${BASE_NAMESPACE_NAME}-$(printf "%03d" $i)"
        if kubectl get namespace "$namespace_name" &> /dev/null; then
            secret_count=$(kubectl get secrets -n "$namespace_name" --no-headers | grep "^${BASE_SECRET_NAME}-" | wc -l)
            total_secrets=$((total_secrets + secret_count))
        fi
    done
    
    log_info "Found $total_secrets secrets across all namespaces"
    log_info "Expected: $((NAMESPACE_COUNT * SECRETS_PER_NAMESPACE)) secrets"
}

# Function to clean up resources
cleanup_resources() {
    log_info "Deleting all created namespaces and their resources..."
    
    for i in $(seq 1 $NAMESPACE_COUNT); do
        namespace_name="${BASE_NAMESPACE_NAME}-$(printf "%03d" $i)"
        if kubectl get namespace "$namespace_name" &> /dev/null; then
            kubectl delete namespace "$namespace_name"
            log_info "Deleted namespace: $namespace_name"
        fi
    done
    
    log_info "Cleanup completed"
}

# Main execution
main() {
    validate_args
    
    log_info "Starting Kubernetes resource creation script"
    log_info "Configuration:"
    log_info "  - Namespaces to create: $NAMESPACE_COUNT"
    log_info "  - Secrets per namespace: $SECRETS_PER_NAMESPACE"
    log_info "  - Total secrets to create: $((NAMESPACE_COUNT * SECRETS_PER_NAMESPACE))"
    
    check_kubectl
    
    create_namespaces
    create_secrets
    verify_resources
    
    log_info "Script completed successfully!"
    log_info "Run '$0 cleanup' to delete all created resources"
}

# Handle script arguments
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        echo "Usage: $0 [namespace_count] [secrets_per_namespace]"
        echo "       $0 cleanup"
        echo ""
        echo "Arguments:"
        echo "  namespace_count: Number of namespaces to create (default: 100)"
        echo "  secrets_per_namespace: Number of secrets to create per namespace (default: 5)"
        echo "  cleanup: Delete all created namespaces and secrets"
        echo ""
        echo "Examples:"
        echo "  $0                    # Create 100 namespaces with 5 secrets each"
        echo "  $0 50                 # Create 50 namespaces with 5 secrets each"
        echo "  $0 50 10              # Create 50 namespaces with 10 secrets each"
        echo "  $0 cleanup            # Delete all created resources"
        echo ""
        echo "Options:"
        echo "  --help, -h: Show this help message"
        exit 0
    elif [[ "$1" == "cleanup" ]]; then
        # For cleanup, we need to determine the namespace count from existing resources
        NAMESPACE_COUNT=$(kubectl get namespaces --no-headers | grep "^${BASE_NAMESPACE_NAME}-" | wc -l)
        if [ "$NAMESPACE_COUNT" -eq 0 ]; then
            log_info "No namespaces found with prefix '$BASE_NAMESPACE_NAME-'"
            exit 0
        fi
        check_kubectl
        cleanup_resources
        exit 0
    fi
    
    main "$@"
fi
