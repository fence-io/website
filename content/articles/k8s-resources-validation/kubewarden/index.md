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

[kubewarden](https://www.kubewarden.io/) is a Kubernetes-native policy engine designed to enforce custom security policies across Kubernetes clusters. This article will delve into the types of policies supported by Kubewarden, the syntax and language used to write these policies, its audit mode and reporting capabilities, observability features, offline evaluation in CI pipelines, and the extensive policies catalog.

# Overview and Purpose

Kubewarden integrates seamlessly into Kubernetes environments, offering a robust solution for implementing and enforcing security policies. It operates based on the principle of warden policies, which are written in [WebAssembly (Wasm)](https://webassembly.org/) format, allowing for lightweight, efficient execution directly within Kubernetes clusters.

## Types of Policies

Kubewarden supports a wide range of policies that can be categorized into three main types:

Admission Policies: These policies are executed during the admission phase of the Kubernetes API server. They can accept, reject, or mutate incoming requests based on predefined rules. Admission policies help ensure that only compliant resources are created or modified within the cluster.

Mutation Policies: Mutation policies modify resource definitions as they pass through the Kubernetes API server. These policies can be used to enforce defaults, add annotations or labels, and ensure that resources adhere to organizational standards before they are persisted.

Validation Policies: These policies validate resource definitions against specific criteria. Validation policies can reject non-compliant resources, helping maintain the desired state of the cluster by ensuring that only valid configurations are allowed.

## Syntax and Language for Writing Policies

Kubewarden policies are written using the WebAssembly (Wasm) technology, which allows policies to be authored in multiple programming languages that can compile to Wasm. The most commonly used languages for writing Kubewarden policies are:

Rust: Known for its performance and safety, Rust is a popular choice for writing Kubewarden policies.
Go: Go offers simplicity and readability, making it another viable option for policy authors.
AssemblyScript: A TypeScript-like language that provides a more approachable syntax for JavaScript and TypeScript developers.
The flexibility of using WebAssembly means that policies can leverage existing libraries and tools within these languages, making it easier to implement complex logic and integrations.

Leveraging Wasm, Kubewarden ensures that policies are executed securely and efficiently with minimal performance overhead. This flexibility allows organizations to address unique security requirements and compliance standards effectively.

Wasm modules are sandboxed and isolated.

## Audit Mode and Reporting

Kubewarden provides an audit mode that allows policies to be evaluated without enforcing them. 
This mode is crucial for organizations looking to understand the impact of potential policies before applying them in a production environment. 
In audit mode, policy evaluations generate detailed reports that highlight which resources would have been accepted, rejected, or mutated if the policies were enforced.

## Observability of the Solution

Observability is a key feature of Kubewarden, providing insights into the performance and effectiveness of policies. Kubewarden integrates with standard observability tools, offering:

**Metrics**: Exported to Prometheus, these metrics provide visibility into policy evaluations, including the number of evaluations, decisions (accept/reject/mutate), and evaluation durations.
**Logs**: Detailed logs are available for each policy evaluation, including the input data, evaluation results, and any errors encountered. These logs can be integrated with centralized logging solutions like Elasticsearch and Grafana.
**Tracing**: By integrating with distributed tracing systems, Kubewarden can provide end-to-end visibility into policy evaluations, helping diagnose performance issues and understand policy impacts.

## Offline Evaluation (Integration in CI Pipelines)

Kubewarden supports offline policy evaluation, making it an excellent fit for CI/CD pipelines. By integrating Kubewarden into CI pipelines, organizations can ensure that resource definitions are compliant with policies before they are deployed to a Kubernetes cluster. This is achieved by:

**Policy Testing**: Policies can be tested against resource definitions during the build phase, catching non-compliant configurations early in the development lifecycle.
**Pre-Deployment Checks**: Resource definitions can be evaluated against policies as part of the deployment pipeline, preventing non-compliant resources from reaching the cluster.
**Feedback Loop**: Developers receive immediate feedback on policy compliance, allowing them to address issues before merging code or deploying applications.

## Policies Catalog

Kubewarden offers a rich catalog of pre-defined policies that address common use cases and best practices. The policies catalog includes:

**Security Policies**: Enforce security best practices, such as requiring certain labels or annotations, enforcing resource limits, and validating container images.
**Compliance Policies**: Ensure resources comply with regulatory requirements and organizational standards.
**Operational Policies**: Improve cluster operations by enforcing naming conventions, validating configuration settings, and ensuring resource consistency.
The policies catalog serves as a starting point for organizations, providing ready-to-use policies that can be customized to meet specific needs.


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

example en rust or typescript 

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
