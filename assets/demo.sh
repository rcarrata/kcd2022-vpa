 demo-magic.sh

# WARNING: This demo to have the VerticalPodAutoscaler operator installed.

pei "# Deploying applications without VPA"
pe "PROJECT=test-novpa-kcd22"
pei ""

pei "# Namespace creation"
pe "oc new-project $PROJECT"
pei ""

pei "# Delete existing LimitRange"
pe "oc delete limitrange --all -n $PROJECT"
pei ""

pei "# Deploying example application"
pe 'cat <<EOF | oc -n $PROJECT apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stress-novpa
spec:
  selector:
    matchLabels:
      app: stress
  replicas: 1
  template:
    metadata:
      labels:
        app: stress
    spec:
      containers:
      - name: stress
        image: polinux/stress
        resources:
          requests:
            memory: "100Mi"
          limits:
            memory: "200Mi"
        command: ["stress"]
        args: ["--vm", "1", "--vm-bytes", "250M"]
EOF'
pei ""

PROMPT_TIMEOUT=5
wait

pei "# Listing resources"
pe "oc get pods"
pei ""

pei "# Listing pod status"
pe "oc describe pod | grep Reason:"
pei ""

pei "#################################"
pei "# Deploying applications with VPA"
pei "#################################"

pei "# Set production namespace name"
pe "PROJECT=test-vpa-devconf22"
pei ""

pei ""
pei "# Namespace creation"
pe "oc new-project $PROJECT"
pei ""

pei "# Delete any existing LimitRange"
pe "oc delete limitrange --all -n $PROJECT"
pei ""

pei "# Now, define the requests as 100Mi and the limits with 200Mi for the container stress. While the application use 150M"
pei ""

pe 'cat <<EOF | oc -n $PROJECT apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: stress
spec:
  selector:
    matchLabels:
      app: stress
  replicas: 1
  template:
    metadata:
      labels:
        app: stress
    spec:
      containers:
      - name: stress
        image: polinux/stress
        resources:
          requests:
            memory: "100Mi"
          limits:
            memory: "200Mi"
        command: ["stress"]
        args: ["--vm", "1", "--vm-bytes", "150M"]
EOF'
pei ""

pei "# List pod resources"
pe "oc get pods -n $PROJECT"
pei ""

pei "# Describe the requests/limits on the application"
pe "oc get pod -l app=stress -o yaml | grep -e limit -e requests -A1"
pei ""

pei "# VPA will use the metrics to adapt the application resources, let's check them"

PROMPT_TIMEOUT=20
wait
pe "oc adm top pod --namespace=$PROJECT --use-protocol-buffers"
pei ""

pei "# VPA creation"
pe "cat <<EOF | oc -n $PROJECT apply -f -
apiVersion: 'autoscaling.k8s.io/v1'
kind: VerticalPodAutoscaler
metadata:
  name: stress-vpa
spec:
  targetRef:
    apiVersion: 'apps/v1'
    kind: Deployment
    name: stress
  resourcePolicy:
    containerPolicies:
      - containerName: '*'
        minAllowed:
          cpu: 100m
          memory: 50Mi
        maxAllowed:
          cpu: 1000m
          memory: 1024Mi
        controlledResources: ['cpu', 'memory']
EOF"
pei ""

pei "# Check the vpa status"
PROMPT_TIMEOUT=18
wait
pe "oc get vpa -n $PROJECT"
pe "oc get vpa stress-vpa -o jsonpath='{.status}' | jq -r ."
pei ""

pei "# The application is now limited by 200M in memory usage"
pe "oc get pod -l app=stress -n $PROJECT -o yaml | grep limits -A1"
pei ""

pei "# We are going to simulate how VPA is going to adjust the resources as long as the application uses more resources"
pe """oc patch deployment stress --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args/3", "value": "250M" }]'"""
pei ""

pei "# The VPA will notice this change and adapt the resources as needed."
pe "oc get pod -l app=stress -o yaml | grep vpa"
pei ""

pei "# After the redeploy, you should see right values on the new pod"
pe "oc get pod -l app=stress -o yaml | grep -e limit -e requests -A1"
pei ''

