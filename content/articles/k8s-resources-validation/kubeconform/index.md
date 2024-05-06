---
authors:
- Charles-Edouard Brétéché
title: Validating Kubernetes resources offline - kubeconform review
date: 2024-05-06
tags:
- Validation
- Kubernetes
- CI
draft: true
featureImage: https://user-images.githubusercontent.com/19731161/142411871-f695e40c-bfa8-43ca-97c0-94c256749732.png
---

In this article, we will explore [kubeconform](https://github.com/yannh/kubeconform), the successor to [kubeval](https://www.kubeval.com/).

Kubeconform is based on the same principles as kubeval, but it is actively maintained and has some unique features.

# Introduction

As the two tools are very similar, I invite you to consult [the article on kubeval](../kubeval/#introduction) which also applies to kubeconform.

# Resource Schemas

Kubeconform uses JSON schemas to validate (or invalidate) the proposed resources. These JSON schemas are created from the OpenAPI schemas published within the Kubernetes GitHub repository.

Unlike kubeval, which is no longer maintained, kubeconform maintains an up-to-date repository of JSON schemas converted from the native schemas published by Kubernetes ([kubeconform fork of kubernetes-json-schema](https://github.com/yannh/kubernetes-json-schema/)). The most recent version supported as of today is `v1.30.0`.

# Installing kubeconform

The kubeconform project documentation suggests installing the binary directly or using a package manager, or using it through a Docker image.

For this article, we will use brew to install it locally:

```bash
brew install kubeconform
```

The docker image can be found at https://ghcr.io/yannh/kubeconform.

# Validation with kubeconform

Unlike kubeval, kubeconform supports the validation of custom resources, provided that you supply the corresponding JSON schemas. We will see more about this later.

Let’s start by validating native resources.

## Validating native resources

Let's try to validate the simple (yet invalid) manifest below:

```yaml
apiVersion: apps/v1
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

If we run kubeconform without any option the `DaemonSet` will be considered invalid:

```
kubeconform manifests.yaml       

manifests.yaml - DaemonSet nginx-ds is invalid: problem validating schema. Check JSON formatting: jsonschema: '/spec' does not validate with https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/master-standalone/daemonset-apps-v1.json#/properties/spec/required: missing properties: 'selector'
```

As noted above, the `selector` field is missing. Let's provide a valid manifest:

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nginx-ds
spec:
  # no replicas field exist in DaemonSet resource
  replicas: 2
  selector:
    matchLabels:
      name: nginx-ds
  template:
    metadata:
      labels:
        name: nginx-ds
    spec:
      containers:
      - image: nginx
        name: nginx
```

This time, running `kubeconform manifests.yaml` passes. Still, the unexpected `replicas` field is not detected.

To make kubeconform detect unexpected fields, we need to specify `--strict`:

```
kubeconform --strict manifests.yaml       

manifests.yaml - DaemonSet nginx-ds is invalid: problem validating schema. Check JSON formatting: jsonschema: '/spec' does not validate with https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/master-standalone-strict/daemonset-apps-v1.json#/properties/spec/additionalProperties: additionalProperties 'replicas' not allowed
```

## Corner cases

As explained in the article on kubeval, schema-based validation is often approximate.

Property type checks work quite well, but the validation of associated values is less reliable. This is because the validation logic is implemented in specific code and does not always form part of the schema definition.

Let's take the example of an invalid label:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cm
  labels:
    # ERROR: a label key must start with an alphanumeric character
    _: invalid
data:
  foo: bar
```

Let's try to validate the resource above with:

```bash
kubeconform --strict manifests.yaml
```

This time kubeconform does not detect the invalid label.

Another simple example is the following, which defines a `Deployment` with a negative number of replicas:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deploy
spec:
  replicas: -1
  selector:
    matchLabels:
      name: deploy
  template:
    metadata:
      labels:
        name: deploy
    spec:
      containers:
      - image: nginx
        name: nginx
```

Here too, `kubeconform --strict manifests.yaml` does not detect the problem even though the resource will be rejected by a cluster:

```
kubectl apply -f manifests.yaml

The Deployment "deploy" is invalid: spec.replicas: Invalid value: -1: must be greater than or equal to 0
```

## Target Kubernetes Version

In the case of native resources, the target version of the cluster is important, as native resources evolve regularly with the appearance of new properties, new API versions, and some API versions are deprecated and then removed, etc.

Therefore, a resource considered valid given one version of Kubernetes may be considered invalid with an older version of Kubernetes.

It is possible to target a specific version of Kubernetes using the `--kubernetes-version` argument.

Let's take, for example, the API `extensions/v1beta1` which was removed from Kubernetes in v1.22:

```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: frontend
spec:
  rules:
  - host: frontend.minikube.local
    http:
      paths:
      - path: /
        backend:
          serviceName: frontend
          servicePort: 80
```

The `Ingress` resource above is considered valid with Kubernetes `v1.20`:

```
kubeconform --kubernetes-version 1.20.0 --strict manifests.yaml
```

While the schema is no longer available in `v1.22`:

```
kubeconform --kubernetes-version 1.22.0 --strict manifests.yaml

manifests.yaml - Ingress frontend failed validation: could not find schema for Ingress
```

## CRDs validation

Let's finish with the validation of custom resources (CRDs).

Kubeconform supports custom resources provided that you can supply it with the corresponding JSON schema.

For instance, using an example from [kubeconform's GitHub](https://github.com/yannh/kubeconform?tab=readme-ov-file#customresourcedefinition-crd-support), we can utilize [Datree's CRDs-catalog](https://github.com/datreeio/CRDs-catalog) which lists the most used CRDs and provides the associated JSON schemas.

Let's take for example an `Issuer` resource of cert manager:

```yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: test-selfsigned
  namespace: cert-manager-test
spec:
  selfSigned: {}
```

Without specifying the location of the schema associated with the `Issuer` resource type, kubeconform is unable to validate the resource:

```
kubeconform --strict manifests.yaml

manifests.yaml - Issuer test-selfsigned failed validation: could not find schema for Issuer
```

In order to enable kubeconform to download the corresponding JSON schema, one can use the `--schema-location` argument:

```
kubeconform --schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' --strict manifests.yaml
```

This time, kubeconform can validate the `Issuer` resource using the schema downloaded from Datree's GitHub repository.

Note that the `--schema-location` argument can be specified as many times as necessary. It is also possible to convert a CRD definition yourself, which is all explained [here](https://github.com/yannh/kubeconform?tab=readme-ov-file#customresourcedefinition-crd-support).

# Conclusion

In conclusion, kubeconform is heavily inspired by kubeval and has taken up the mantle to become its worthy successor.

Both tools operate in exactly the same way based on JSON schema, and kubeconform maintains an up-to-date version of the schemas for native resources.

Finally, kubeconform adds support for custom resources, which significantly broadens the tool's scope. Their use, however, remains quite complex, especially in the case of a custom resource whose schema is not publicly available on the internet.

In summary, kubeconform is a significant step forward for users of kubeval, providing a satisfactory tool for use without custom resources. However, it remains limited in the case of intensive use of CRDs.

# Stay tuned!

The next article will explore a tool more suited to modern Kubernetes usage with enhanced support for custom resources. Stay tuned for the next episode!
