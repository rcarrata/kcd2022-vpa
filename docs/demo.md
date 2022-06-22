# DevConf Demo - Automatically adjust requests / limits when Apps are OOMKilled

## Without VPA

1. Create a project without LimitRange

```bash
PROJECT=test-novpa-uc2-$RANDOM
```

```bash
oc new-project $PROJECT
```

2. Delete any preexistent LimitRange:

```bash
oc -n $PROJECT delete limitrange --all
```

3. Deploy stress application into the ns:

```bash
cat <<EOF | oc -n $PROJECT apply -f -
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
EOF
```

We defined the requests as 100Mi and the limits with 200Mi for the container stress.

On the other hand, we used the stress image, and as in the [Image Stress Documentation](https://linux.die.net/man/1/stress) is described, we can define the arguments for allocate certain amount of memory:

```md
- -m, --vm N: spawn N workers spinning on malloc()/free()
- --vm-bytes B: malloc B bytes per vm worker (default is 256MB) 
```

So we defined 250M of memory allocation by the stress process, that's more than the limits of the container is defined, exceeding the Container's memory limit, and this will produce an OOMKilled.

```sh
oc get pod
NAME                            READY   STATUS      RESTARTS   AGE
stress-novpa-7b9459559c-hrgwr   0/1     OOMKilled   0          6s
```

In Kubernetes, every scheduling decision is always made based on the resource requests. Whatever number you put there, the scheduler will use it to allocate place for your pod.

## With VPA

1. Create a project without LimitRange

```bash
PROJECT=test-vpa-uc2-$RANDOM
```

```bash
oc new-project $PROJECT
```

2. Delete any preexistent LimitRange:

```bash
oc -n $PROJECT delete limitrange --all
```

3. Deploy stress application into the ns:

```bash
cat <<EOF | oc -n $PROJECT apply -f -
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
EOF
```

We defined the requests as 100Mi and the limits with 200Mi for the container stress.

On the other hand, we used the stress image, and as in the [Image Stress Documentation](https://linux.die.net/man/1/stress) is described, we can define the arguments for allocate certain amount of memory:

```md
- -m, --vm N: spawn N workers spinning on malloc()/free()
- --vm-bytes B: malloc B bytes per vm worker (default is 256MB) 
```

So we defined 150M of memory allocation by the stress process, that's it's between the request and limits defined.

4. Check that the pod is up && running:

```sh
oc get pod
NAME                      READY   STATUS    RESTARTS   AGE
stress-7d48fdb6fb-j46b8   1/1     Running   0          35s

oc logs -l app=stress
stress: info: [1] dispatching hogs: 0 cpu, 0 io, 1 vm, 0 hdd
```

5. Check that the request and limits generated in Pod

```bash
oc get pod -l app=stress -o yaml | grep limit -A1
        limits:
          memory: 200Mi
```

```
oc get pod -l app=stress -o yaml | grep requests -A1
        requests:
          memory: 100Mi
```

6. Check the metrics of the pod deployed:

```bash
oc adm top pod --namespace=$PROJECT --use-protocol-buffers
NAME                      CPU(cores)   MEMORY(bytes)
stress-7d48fdb6fb-j46b8   1019m        115Mi
```

7. It is possible to set a range for the autoscaling: minimum and maximum values, for the requests. Apply the VPA with the minAllowed and maxAllowed as described:

```sh
cat <<EOF | oc -n $PROJECT apply -f -
apiVersion: "autoscaling.k8s.io/v1"
kind: VerticalPodAutoscaler
metadata:
  name: stress-vpa
spec:
  targetRef:
    apiVersion: "apps/v1"
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
        controlledResources: ["cpu", "memory"]
EOF
```

So since the only truly important things is the requests parameter, the Vertical Pod Autoscaler will always work with this. Whenever you define vertical autoscaling for your app, you are defining what the requests should be.

8. After a couple of minutes, check the VPA to see the Memory and CPU suggested:

```sh
oc get vpa
NAME         MODE   CPU   MEM       PROVIDED   AGE
stress-vpa   Auto   1     262144k   True       81s
```

```sh
oc get vpa hamster-vpa -o jsonpath='{.status}' | jq -r .
{
  "conditions": [
    {
      "lastTransitionTime": "2021-12-20T20:48:09Z",
      "status": "True",
      "type": "RecommendationProvided"
    }
  ],
  "recommendation": {
    "containerRecommendations": [
      {
        "containerName": "stress",
        "lowerBound": {
          "cpu": "746m",
          "memory": "262144k"
        },
        "target": {
          "cpu": "1",
          "memory": "262144k"
        },
        "uncappedTarget": {
          "cpu": "1388m",
          "memory": "262144k"
        },
        "upperBound": {
          "cpu": "1",
          "memory": "1Gi"
        }
      }
    ]
  }
}
```

* **Lower Bound**: when your pod goes below this usage, it will be evicted and downscaled.

* **Target**: this will be the actual amount configured at the next execution of the admission webhook. (If it already has this config, no changes will happen (your pod won’t be in a restart/evict loop). Otherwise, the pod will be evicted and restarted using this target setting.)

* **Uncapped Target**: what would be the resource request configured on your pod if you didn’t configure upper limits in the VPA definition.

* **Upper Bound**: when your pod goes above this usage, it will be evicted and upscaled.


9. Let's increase the memory allocation by the stress process in our container in our stress pod, above the defined limit:

```sh
oc get pod -l app=stress -n $PROJECT -o yaml | grep limits -A1
        limits:
          memory: 200Mi
```

the memory limit is 200Mi as is defined in the Deployment.

Increase the memory allocation in the pod patching the arg of the --vm-bytes to 250M:

```sh
oc patch deployment stress --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args/3", "value": "250M" }]'
```

10. Check the pods to see if the OOMKilled or Crashloopbackoff state it's in our stress pod:

```sh
oc get pod -w
NAME                      READY   STATUS        RESTARTS   AGE
stress-7b9459559c-ntnrv   1/1     Running       0          5s
stress-7d48fdb6fb-j46b8   1/1     Terminating   0          22m
```

11. Check the VPA resources and :

```sh
 oc get pod -l app=stress -o yaml | grep vpa
      vpaObservedContainers: stress
      vpaUpdates: 'Pod resources updated by stress-vpa: container 0: cpu request,
```

8. Check that the VPA changed automatically the requests and limits in the POD, but NOT in the deployment or replicaset:

```sh
oc get pod -l app=stress -o yaml | grep requests -A2
        requests:
          cpu: "1"
          memory: 262144k
```

```sh
oc get pod -l app=stress -o yaml | grep limits -A1
        limits:
          memory: 500Mi
```

So what happens to the limits parameter of your pod? Of course they will be also adapted, when you touch the requests line. The VPA will proportionally scale limits.

As mentioned above, this is proportional scaling: in our default stress deployment manifest, we have the following requests to limits ratio:

* CPU: 100m -> 200m: 1:4 ratio
* memory: 100Mi -> 250Mi: 1:2.5 ratio

So when you get a scaling recommendation, it will respect and keep the same ratio you originally configured, and proportionally set the new values based on your original ratio.

8. The deployment of stress app is not changed at all, the VPA just is changing the Pod spec definition:

```
oc get deployment stress -o yaml | egrep -i 'limits|request' -A1         
         requests:
            memory: "100Mi"
          limits:
            memory: "200Mi"
```

But don’t forget, your limits are almost irrelevant, as the scheduling decision (and therefore, resource contention) will be always done based on the requests.

Limits are only useful when there's resource contention or when you want to avoid uncontrollable memory leaks.
