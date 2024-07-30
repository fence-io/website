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

**Go**: Offers simplicity and readability, making it another viable option for policy authors.

**Rego**: High-level declarative language used in Open Policy Agent and Gatekeeper for defining and enforcing policies.

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

```sh
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

Let's create a very basic Kubewarden policy in Go. This policy will reject pods with names in a predefined deny list. For the complete code, please look at [the example](https://gist.github.com/flavio/4995b1288d27c726c3524a4067ab8715).

```go
...
func validate(payload []byte) ([]byte, error) {
	// Create a ValidationRequest instance from the incoming payload
	validationRequest := kubewarden_protocol.ValidationRequest{}
	err := json.Unmarshal(payload, &validationRequest)
	if err != nil {
		return kubewarden.RejectRequest(
			kubewarden.Message(err.Error()),
			kubewarden.Code(httpBadRequestStatusCode))
	}

	// Create a Settings instance from the ValidationRequest object
	settings, err := NewSettingsFromValidationReq(&validationRequest)
	if err != nil {
		return kubewarden.RejectRequest(
			kubewarden.Message(err.Error()),
			kubewarden.Code(httpBadRequestStatusCode))
	}

	// Access the **raw** JSON that describes the object
	podJSON := validationRequest.Request.Object

	// Try to create a Pod instance using the RAW JSON we got from the
	// ValidationRequest.
	pod := &corev1.Pod{}
	if err = json.Unmarshal([]byte(podJSON), pod); err != nil {
		return kubewarden.RejectRequest(
			kubewarden.Message(
				fmt.Sprintf("Cannot decode Pod object: %s", err.Error())),
			kubewarden.Code(httpBadRequestStatusCode))
	}

	logger.DebugWithFields("validating pod object", func(e onelog.Entry) {
		e.String("name", pod.Metadata.Name)
		e.String("namespace", pod.Metadata.Namespace)
	})

	if settings.IsNameDenied(pod.Metadata.Name) {
		logger.InfoWithFields("rejecting pod object", func(e onelog.Entry) {
			e.String("name", pod.Metadata.Name)
			e.String("denied_names", strings.Join(settings.DeniedNames, ","))
		})

		return kubewarden.RejectRequest(
			kubewarden.Message(
				fmt.Sprintf("The '%s' name is on the deny list", pod.Metadata.Name)),
			kubewarden.NoCode)
	}

	return kubewarden.AcceptRequest()
}
...
```

## Build and Package the Policy

1. **Install TinyGo**:

The official Go compiler can't produce WebAssembly binaries that run outside the browser. Therefore, you must use TinyGo to build the policy.

```sh
wget https://github.com/tinygo-org/tinygo/releases/download/v0.25.0/tinygo_0.25.0_amd64.deb
sudo dpkg -i tinygo_0.25.0_amd64.deb
```

2. **Compile the Policy**:

Use `TinyGo` to compile the policy into a WebAssembly module.

```sh
tinygo build -o policy.wasm -target=wasi main.go
```

## Test & publish the Policy

1. **Push the Policy to a Registry**:

You need to push the compiled WebAssembly module to a registry that Kubewarden can access. Here, we will use [`kwctl`](https://github.com/kubewarden/kwctl/?tab=readme-ov-file#install) to push the module to an OCI-compliant registry.

Policies have to be annotated before to be pushed and executed by the Kubewarden policy-server in a Kubernetes cluster. Create `metadata.yaml` file.

```yaml
rules:
    - apiGroups: [""]
    apiVersions: ["*"]
    resources: ["*"]
    operations: ["CREATE"]
mutating: false
contextAware: false
executionMode: gatekeeper
annotations:
    io.kubewarden.policy.title: Pod Name Deny List Policy
    io.kubewarden.policy.description: Pods with names in a predefined deny list are rejected
    io.kubewarden.policy.author: fence.io
    io.kubewarden.policy.url: https://github.com/...
    io.kubewarden.policy.source: https://github.com/...
    io.kubewarden.policy.license: Apache-2.0
    io.kubewarden.policy.usage: |
        This policy allow you to reject pods if pod name is in a predefined deny list.
```

Annotate the policy:

```sh
kwctl annotate policy.wasm --metadata-path metadata.yaml --output-path annotated-policy.wasm
```

Push the policy:

```sh
kwctl push annotated-policy.wasm <your-registry>/nod-name-deny-list-policy:v0.0.1
```

2. **E2E testing**:

You can automate end-to-end testing of your policy against Kubernetes requests to ensure expected behavior, even for context-aware policies that require access to a running cluster.

You have to pull your policy to kwctl local store first:

```sh
    kwctl pull registry://<your-registry>/nod-name-deny-list-policy:v0.0.1
```

Run the test:

```sh
kwctl run \
    --settings-json '{"denied_names": ["test"]}' \
    -r test_data/pod.json \
    registry://<your-registry>/nod-name-deny-list-policy:v0.0.1
```

## Deploy the Policy using Kubewarden

Create a ClusterAdmissionPolicy resource to deploy your policy:

```yaml
apiVersion: policies.kubewarden.io/v1alpha2
kind: ClusterAdmissionPolicy
metadata:
name: generated-policy
spec:
module: registry://<your-registry>/nod-name-deny-list-policy:v0.0.1
rules:
    - apiGroups: [""]
        apiVersions: ["v1"]
        resources: ["pods"]
mutating: false
settings:
denied_names: [ "test" ]
```

# Conclusion

Kubewarden emerges as a valuable tool for Kubernetes administrators and security teams seeking to implement and enforce robust security policies effectively. Its use of WebAssembly for policy execution, comprehensive policy library, seamless Kubernetes integration, and active community support make it a compelling choice for enhancing Kubernetes security with policy-driven controls.

However, adopting Kubewarden requires a learning curve for Wasm and Kubernetes concepts, and effective policy development may demand initial investment in understanding and implementation.
