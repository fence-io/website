---
authors:
- sara
title: Kubernetes Policy Engine - kubewarden
date: 2024-06-14
tags:
- Policy
- Kubernetes
- Wasm
- Runtime
- CI
images: 
- kubewarden.png
series: ["Kubernetes Policy Engine"]
series_order: 1
series_opened: true
series_title: Kubewarden review
slug: "kubewarden-review"
---


# Introduction

[kubewarden](https://www.kubewarden.io/) is a Kubernetes-native policy engine designed to enforce custom security policies across Kubernetes clusters. This article will delve into the types of policies supported by Kubewarden, the syntax and language used to write these policies, its audit mode and reporting capabilities, observability features, offline evaluation in CI pipelines, and the extensive policies catalog.

# Overview and Purpose

Kubewarden integrates seamlessly into Kubernetes environments, offering a robust solution for implementing and enforcing security policies. It operates based on the principle of warden policies, which are written in [WebAssembly (Wasm)](https://webassembly.org/) format, allowing for lightweight, efficient execution directly within Kubernetes clusters.

## Types of Policies

The policies are executed during the admission phase of the Kubernetes API server. They can accept, reject, or mutate incoming requests based on predefined rules to help ensuring that only compliant resources are created or modified within the cluster.

Kubewarden policies can be categorized into two main types:

**Mutation Policies**: Mutation policies modify resource definitions as they pass through the Kubernetes API server. These policies can be used to add annotations or labels, and ensure that resources adhere to organizational standards before they are persisted.

**Validation Policies**: These policies validate resource definitions against specific criteria. Validation policies can reject non-compliant resources, helping maintain the desired state of the cluster by ensuring that only valid configurations are allowed.

For more information about the different types of policies, please refer to this [link](https://docs.kubewarden.io/tutorials/writing-policies/wasi/raw-policies).

## Syntax and Language for Writing Policies

Kubewarden policies are written using the [WebAssembly (Wasm)](https://webassembly.org/) technology, which allows policies to be written in multiple programming languages that can compile to Wasm ([list of supported languages](https://github.com/appcypher/awesome-wasm-langs)). The most commonly used languages for writing Kubewarden policies are:

**Rust**: Known for its performance and safety, Rust is a popular choice for writing Kubewarden policies.

**Go**: Go offers simplicity and readability, making it another viable option for policy authors.

**AssemblyScript**: A TypeScript-like language that provides a more approachable syntax for JavaScript and TypeScript developers.

The flexibility of using **WebAssembly** means that policies can leverage existing libraries and tools within these languages, making it easier to implement complex logic and integrations.

Leveraging **Wasm**, Kubewarden ensures that policies are executed securely and efficiently with minimal performance overhead. This flexibility allows organizations to address unique security requirements and compliance standards effectively.

**Wasm** modules are sandboxed and isolated.

## Audit Mode and Reporting

Kubewarden provides an [audit mode](https://docs.kubewarden.io/explanations/audit-scanner) that allows policies to be evaluated without enforcing them. 

This mode is crucial for organizations looking to understand the impact of potential policies before applying them in a production environment. 

In **audit mode**, policy evaluations generate detailed reports that highlight which resources would have been accepted, rejected, or mutated if the policies were enforced.

The results of the audit scanner are stored in a [PolicyReport](https://docs.kubewarden.io/explanations/audit-scanner/policy-reports) format, allowing integration with the [Policy Reporter UI](https://kyverno.github.io/policy-reporter/).

## Observability of the Solution

Observability is a key feature of Kubewarden, providing insights into the performance and effectiveness of policies. Kubewarden integrates with standard observability tools, offering:

**Metrics**: Exported to Prometheus, these metrics provide visibility into policy evaluations, including the number of evaluations, decisions (accept/reject/mutate), and evaluation durations.

**Logs**: Detailed logs are available for each policy evaluation, including the input data, evaluation results, and any errors encountered. These logs can be integrated with centralized logging solutions like Elasticsearch and Grafana.

**Tracing**: By integrating with distributed tracing systems, Kubewarden can provide end-to-end visibility into policy evaluations, helping diagnose performance issues and understand policy impacts.

## Offline Evaluation (Integration in CI Pipelines)

Kubewarden supports offline policy evaluation, making it an excellent fit for CI/CD pipelines. By integrating Kubewarden into CI pipelines, organizations can ensure that resource definitions are compliant with policies before they are deployed to a Kubernetes cluster. This is achieved by:

**Policy Testing**: Policies can be tested against resource definitions during the build phase, catching non-compliant configurations early in the development lifecycle. More details about policy testing are [here](https://docs.kubewarden.io/tutorials/testing-policies).

The testing approach involves developers who create the policies, ensuring they receive immediate feedback on policy compliance in the CI pipeline. This allows them to address issues before merging code.

Additionally, cluster operators benefit from a feedback loop where resource definitions are evaluated against policies as part of the deployment pipeline, preventing non-compliant resources from reaching the cluster.

## Policies Catalog

Kubewarden offers [pre-defined policies](https://artifacthub.io/packages/search?kind=13&sort=relevance&page=1) that address common use cases and best practices. The policies catalog includes:

**Security Policies**: Enforce security best practices, such as Pod Security Policy standard, and validating container images.

**Compliance Policies**: Ensure resources adhere to regulatory requirements and organizational standards, such as enforcing or validating the presence of specific labels or annotations.

**Operational Policies**: Improve cluster operations by enforcing naming conventions, validating configuration settings, and ensuring resource consistency.

This list serves as a starting point for organizations, providing ready-to-use policies that can be customized to meet specific needs.

# Installation

Installing Kubewarden involves several steps to set up the necessary components for Kubernetes integration and policy enforcement. Here’s a general guide on how to install Kubewarden:

Requirement: Install [cert-manager](https://cert-manager.io/) before the kubewarden-controller chart.

```bash
helm repo add jetstack https://charts.jetstack.io

helm install --wait --namespace cert-manager --create-namespace \
	--set installCRDs=true cert-manager jetstack/cert-manager

helm repo add kubewarden https://charts.kubewarden.io

helm repo update kubewarden

helm install --wait -n kubewarden --create-namespace kubewarden-crds kubewarden/kubewarden-crds

helm install --wait -n kubewarden kubewarden-controller kubewarden/kubewarden-controller

helm install --wait -n kubewarden kubewarden-defaults kubewarden/kubewarden-defaults
```

# Example

Let's create a very basic Kubewarden policy in Go. This policy will ensure that any Kubernetes resource has a specific label. (The policy created using [go-policy-template](https://github.com/kubewarden/go-policy-template)).


```go
package main

import (
    "encoding/json"
    "fmt"
    "os"

    "github.com/kubewarden/policy-sdk-go/policy"
    "github.com/kubewarden/policy-sdk-go/protocol"
)

type Settings struct {
    RequiredLabelKey   string `json:"required_label_key"`
    RequiredLabelValue string `json:"required_label_value"`
}

func validate(payload []byte) ([]byte, error) {
    var req protocol.ValidationRequest
    if err := json.Unmarshal(payload, &req); err != nil {
        return nil, fmt.Errorf("cannot unmarshal validation request: %w", err)
    }

    var settings Settings
    if err := json.Unmarshal(req.Settings, &settings); err != nil {
        return nil, fmt.Errorf("cannot unmarshal settings: %w", err)
    }

    labels := req.Request.Object.Object["metadata"].(map[string]interface{})["labels"].(map[string]interface{})
    if value, found := labels[settings.RequiredLabelKey]; !found || value != settings.RequiredLabelValue {
        return policy.Deny(fmt.Sprintf("missing required label: %s=%s", settings.RequiredLabelKey, settings.RequiredLabelValue)), nil
    }

    return policy.Allow(), nil
}

func main() {
    policy.Entrypoint(validate)
}
```

## Build and Package the Policy

1. **Install TinyGo**:

The official Go compiler can't produce WebAssembly binaries that run outside the browser. Therefore, you must use TinyGo to build the policy.

   ```sh
   wget https://github.com/tinygo-org/tinygo/releases/download/v0.25.0/tinygo_0.25.0_amd64.deb
   sudo dpkg -i tinygo_0.25.0_amd64.deb
   ```

2. **Compile the Policy**:

   Use TinyGo to compile the policy into a WebAssembly module.

   ```sh
   tinygo build -o policy.wasm -target=wasi main.go
   ```
   
## Test the Policy

You can use wasmtime to test your Wasm module locally.

```sh
curl https://wasmtime.dev/install.sh -sSf | bash
```

Create a settings.json file with the required label settings:

```json
	{
		"required_label_key": "environment",
		"required_label_value": "production"
	}
```

Create a test-input.json file with a test Kubernetes resource:

```json
{
    "request": {
        "object": {
            "metadata": {
                "labels": {
                    "environment": "production"
                }
            }
        }
    },
    "settings": {
        "required_label_key": "environment",
        "required_label_value": "production"
    }
}
```

Run the policy with Wasmtime and test input:

```sh
cat test-input.json | wasmtime policy.wasm
```

## Deploy the Policy

1. **Push the Policy to a Registry**:

   You need to push the compiled WebAssembly module to a registry that Kubewarden can access. Here, we will use `cosign` to sign and push the module to an OCI-compliant registry.

   Install `cosign`:

   ```sh
   go install github.com/sigstore/cosign/cmd/cosign@latest
   ```

   Push the WebAssembly module:

   ```sh
   cosign sign-blob --key cosign.key policy.wasm
   ```

2. **Deploy the Policy using Kubewarden**:

   Create a ClusterAdmissionPolicy resource to deploy your policy:

   ```yaml
   apiVersion: policies.kubewarden.io/v1
   kind: ClusterAdmissionPolicy
   metadata:
     name: my-policy
   spec:
     module: registry://<your-registry>/policy:latest
     rules:
       - apiGroups: [""]
         apiVersions: ["v1"]
         resources: ["pods"]
     mutating: false
     settings:
       required_label_key: "example-key"
       required_label_value: "example-value"
   ```

Replace `<your-registry>` with the actual registry where you pushed your WebAssembly module.

# Conclusion:

Kubewarden emerges as a valuable tool for Kubernetes administrators and security teams seeking to implement and enforce robust security policies effectively. Its use of WebAssembly for policy execution, comprehensive policy library, seamless Kubernetes integration, and active community support make it a compelling choice for enhancing Kubernetes security with policy-driven controls.

 However, adopting Kubewarden requires a learning curve for Wasm and Kubernetes concepts, and effective policy development may demand initial investment in understanding and implementation.
