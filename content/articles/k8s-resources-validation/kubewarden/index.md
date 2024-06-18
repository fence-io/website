---
authors:
- sara
title: Validating Kubernetes resources offline - kubewarden
date: 2024-06-14
tags:
- Validation
- Kubernetes
- CI
images: 
- kubewarden.png
series: ["Offline Kubernetes Validation"]
series_order: 3
series_opened: true
series_title: Kubewarden review
slug: "kubewarden-review"
---


# Introduction

[kubewarden](https://www.kubewarden.io/) is a Kubernetes-native policy engine designed to enforce custom security policies across Kubernetes clusters. Here’s a review highlighting its features, capabilities, and benefits.

# Overview and Purpose

Kubewarden integrates seamlessly into Kubernetes environments, offering a robust solution for implementing and enforcing security policies. It operates based on the principle of warden policies, which are written in [WebAssembly (Wasm)](https://webassembly.org/) format, allowing for lightweight, efficient execution directly within Kubernetes clusters.

## Policy Enforcement

Kubewarden enables the creation and enforcement of custom policies. Policies can be defined to validate Kubernetes resource configurations, container images, runtime behaviors, and more.
  
Leveraging Wasm, Kubewarden ensures that policies are executed securely and efficiently with minimal performance overhead. Wasm modules are sandboxed and isolated.

## Extensibility and Customization

Users can develop and deploy their own policies using familiar programming languages compiled to Wasm. This flexibility allows organizations to address unique security requirements and compliance standards effectively.

## Integration with Kubernetes Ecosystem

Kubewarden seamlessly integrates with Kubernetes through admission controllers, validating requests to the Kubernetes API server in real-time. It supports integration with tools like Kubernetes Policy Controller [KubeScor](https://kube-score.com/) and other Kubernetes-native security solutions.

Kubewarden is designed to scale across large Kubernetes deployments, ensuring efficient policy enforcement without impacting cluster performance. Its architecture and use of Wasm technology contribute to minimal resource consumption.

## Community and Support

The Kubewarden community and ecosystem offer a growing library of pre-defined policies addressing common security concerns such as container image vulnerabilities, resource limits, pod security contexts, network policies, and more.

Backed by an active open-source community, Kubewarden benefits from ongoing development, updates, and contributions from security professionals and Kubernetes enthusiasts worldwide.

# Installation

Installing Kubewarden involves several steps to set up the necessary components for Kubernetes integration and policy enforcement. Here’s a general guide on how to install Kubewarden:

Requirement: Install [cert-manager](https://cert-manager.io/) before the kubewarden-controller chart.

```bash
helm repo add jetstack https://charts.jetstack.io

helm install --wait --namespace cert-manager --create-namespace \
	--set installCRDs=true cert-manager jetstack/cert-manager

helm repo add kubewarden https://charts.kubewarden.io

helm repo update kubewarden
```

# Usage 

**Create policy**

Here is an example of a policy written in Go that checks if the label `app.kubernetes.io/component: web` exists in the pod labels.

```go
package main

import (
	"encoding/json"
	"fmt"
	"os"
)

type PolicyData struct {
	Resource Resource `json:"resource"`
}

type Resource struct {
	Manifest Manifest `json:"manifest"`
}

type Manifest struct {
	Metadata Metadata `json:"metadata"`
}

type Metadata struct {
	Labels map[string]string `json:"labels"`
}

func main() {
	var inputData PolicyData
	err := json.NewDecoder(os.Stdin).Decode(&inputData)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error decoding input: %v", err)
		os.Exit(1)
	}

	labels := inputData.Resource.Manifest.Metadata.Labels

	if val, ok := labels["app.kubernetes.io/component"]; !ok || val != "web" {
		fmt.Println(`{"allowed": false, "message": "Pod must have label 'app.kubernetes.io/component: web'."}`)
		return
	}

	fmt.Println(`{"allowed": true}`)
}
```

**Build the policy into wasm**

Build the Go code into a WebAssembly (Wasm) module using the Kubewarden CLI [kwctl](https://github.com/kubewarden/kwctl?tab=readme-ov-file#install):

```bash
kwctl build -t wasm main.go
```

This command generates a `main.wasm` file in the current directory, which is the compiled WebAssembly module of your policy.

**Create a Policy Bundle**

Create a policy bundle directory structure with your Wasm module and a metadata file (`policy.yaml`) describing your policy:

```yaml
apiVersion: policies.kubewarden.io/v1alpha2
kind: Policy
metadata:
  name: kubewarden-example
spec:
  module: main.wasm
  rules:
    - operations: ["CREATE", "UPDATE"]
      description: "Ensure Pod has label 'app.kubernetes.io/component: web'"
      message: "Pod must have label 'app.kubernetes.io/component: web'."
      query: ""
```

**Deploy the Policy Bundle**

Deploy the policy bundle to your Kubernetes cluster using [kwctl](https://github.com/kubewarden/kwctl?tab=readme-ov-file#install):

```bash
kwctl apply -f .
```

This command deploys the policy bundle (including `main.wasm` and `policy.yaml`) to your Kubernetes cluster, making it available for enforcement.

# Conclusion:

Kubewarden emerges as a valuable tool for Kubernetes administrators and security teams seeking to implement and enforce robust security policies effectively. Its use of WebAssembly for policy execution, comprehensive policy library, seamless Kubernetes integration, and active community support make it a compelling choice for enhancing Kubernetes security with policy-driven controls.
