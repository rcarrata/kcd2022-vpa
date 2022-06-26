# Kubernetes Community Days Berlin 2022 - Predictive Autoscaling Patterns in Kubernetes

* [**KCD22 Session - Predictive Autoscaling Patterns in Kubernetes**](https://community.cncf.io/events/details/cncf-kcd-berlin-presents-kubernetes-community-days-berlin-2022-1/#event-info)

## Abstract

During this session we will demonstrate how your applications can benefit from Vertical Pod Autoscaler improving the responsiveness and performance of your workloads in Kubernetes environments.

We will analyze the best practices and deployment patterns to include in an easy way these new features that can be integrated with your applications custom metrics.

After this session, you will understand the implementation details and the architecture highlights, freeing your developers from the necessity of setting up-to-date resource limits and requests for the containers in their pods allowing them to focus on their business application development, making possible scale applications in a predictive and efficient way.

## Run the Demo

* Prerequisites: Install VPA in your k8s/OpenShift cluster
  - k8s: https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler#installation
  - OpenShift (with Operators): https://docs.openshift.com/container-platform/latest/nodes/pods/nodes-pods-vertical-autoscaler.html

* Run the demo:

```sh
git clone https://github.com/rcarrata/kcd2022-vpa.git
bash assets/demo.sh
```

Enjoy! :)

# Demo Walkthrough

If you want to sneak peak the demo without running it in your k8s cluster, check out this walkthrough:

* [Demo Predictive Autoscaling Patterns in Kubernetes Walkthrough](docs/demo.md)

## Slides

* [KCD22Berlin Slides](https://es.slideshare.net/RobertoCarratalaSanc1/kcd2022-predictive-autoscaling-patterns-in-k8spdf-252062444)

## Contributors / Maintainers

* [Roberto Carratalá](github.com/rcarrata)
