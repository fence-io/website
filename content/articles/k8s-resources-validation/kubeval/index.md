---
authors:
- Charles-Edouard Brétéché
title: Validating Kubernetes resources offline - kubeval review
date: 2024-05-05
tags:
- Validation
- Kubernetes
- CI
featureImage: https://opengraph.githubassets.com/0fb34fac5b9bbfc8c22fe2e8d5025cf835fff5451d942903464a45131e8b85df/instrumenta/kubeval
---

In this article, we will discuss validating Kubernetes resource definitions using the tool [kubeval](https://www.kubeval.com/).

Before we begin, it's important to note that kubeval is no longer maintained, and the author advises migrating to [kubeconform](https://github.com/yannh/kubeconform). We will explore kubeconform in the [next article](../kubeconform/).

# Introduction

Validating Kubernetes resources is very useful for detecting non-compliant resources before applying them to a cluster. The most common use case is to perform validation during CI to validate (or invalidate) the quality of a pull request.

In this specific case, a cluster is generally not available, and validation must therefore be performed offline. The tool must be able to function autonomously and validate (or invalidate) the supplied manifests.

# Kubernetes-side Validation

Validation within a Kubernetes cluster is performed differently depending on the types of resources used.

For **native Kubernetes resources** (`ConfigMap`, `Deployment`, `Pod`, etc.), validation is done by dedicated code. The validation logic is therefore hard to leverage as it is not expressed in a declarative manner.

Next comes the case of **custom resources** (described using CRDs). These types of resources are not native and must adhere to a more or less precise schema. This schema is used by Kubernetes to validate a resource submitted to it.

Finally, it is also possible to enrich the validation logic by adding webhooks invoked by the Kubernetes API server at the time of resource admission.

## Resource Schemas

The schemas for native or custom resources are expressed using OpenAPI v2 (or v3 for more recent versions of Kubernetes). These schemas are more or less precise in the case of native resources, with the validation logic being implemented in dedicated code.

These schemas are used by most resource validation tools to validate (or not) the proposed resources.

## Validation Webhooks

Until recently, validation webhooks were standard services, internal or external to the cluster, invoked by the API server during the admission of a resource.

These webhooks could implement a completely customized logic, and it is generally excluded that a validation tool could reproduce the logic embedded in these different services.

Recently, the introduction of CEL and validation policies have allowed programming the behavior of the API server in a declarative manner. Validation tools are theoretically able to apply the same validation policies as the API server.

# Installing kubeval

The kubeval project documentation suggests installing the binary directly or using a package manager, or using it through a Docker image.

For this article, we will use the Docker image, as installation with brew failed since the project is no longer maintained :shrug:

# Validation with kubeval

First, let's note that kubeval [does not support validation of CRDs](https://www.kubeval.com/#crds).
The recommended workaround is to exclude custom (unknown) resources.

Let's try to validate the simple (yet invalid) manifest below:

```yaml
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: nginx-ds
spec:
  # no replicas field exist in DaemonSet resource
  replicas: 2
  template:
    spec:
      containers:
      - image: nginx
        name: nginx
```

If we run kubeval without any option the `DaemonSet` will be considered valid:

```
docker run -it -v ${PWD}:/work garethr/kubeval work/manifests.yaml

PASS - work/manifests.yaml contains a valid DaemonSet (nginx-ds)
```

To make kubeval detect additional fields, we need to specify `--strict`:

```
docker run -it -v ${PWD}:/work garethr/kubeval work/manifests.yaml --strict

WARN - work/manifests.yaml contains an invalid DaemonSet (nginx-ds) - replicas: Additional property replicas is not allowed
```

## Target Kubernetes Version

In the case of native resources, the target version of the cluster is important, as native resources evolve regularly with the appearance of new properties, new API versions, some API versions are deprecated and then removed, etc.

Therefore, a resource considered valid given one version of Kubernetes may be considered invalid with an older version of Kubernetes.

It is possible to target a specific version of Kubernetes using the `-v` argument. Unfortunately, the tool relies on schemas published on the website https://kubernetesjsonschema.dev which stopped at version 1.18 of Kubernetes.

# Conclusion

It seems somewhat irrelevant to push the study of kubeval much further. It is clear that the tool is outdated, is no longer maintained, is at least 10 versions of Kubernetes behind, and has therefore clearly become obsolete.

It remains, however, the first tool to have popularized offline validation of Kubernetes resources and it deserved to be mentioned.

We will see other more modern tools in future articles. Stay tuned for the [next episode](../kubeconform/)!
