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
---

Dans cet article nous allons étudier [kubeconform](https://github.com/yannh/kubeconform), le successeur de [kubeval](https://www.kubeval.com/).

Kubeconform se base sur les mêmes principes que kubeval, il est cependant maintenu et possède certaines fonctionnalités qui lui sont propres.

# Introduction

Les deux outils étant très similaires je vous invite a consulter l'article sur kubeval qui s'applique également a kubeconform.

# Resource Schemas

Kubeconform utilise les JSON schemas pour valider (ou invalider) les resources proposées. Les JSON schemas sont créés a partir de schémas OpenAPI publiés au sein du repository GitHub de Kubernetes.

A l'inverse de kubeval qui n'est plus maintenu, kubeconform maintient un repository a jour des JSON schémas convertis a partir des schémas natifs publiés par Kubernetes ([Kubeconform fork of kubernetes-json-schema](https://github.com/yannh/kubernetes-json-schema/)). La version la plus récente supportée a ce jour est `v1.30.0`.

# Installing kubeconform

The kubeconform project documentation suggests installing the binary directly or using a package manager, or using it through a Docker image.

For this article, we will use the brew to install it locally:

```bash
brew install kubeconform
```

The docker image can be found at ghcr.io/yannh/kubeconform

# Validation with kubeconform

Contrairement a kubeval, kubeconform supporte la validation des resources customs, a la condition que vous founissiez les JSON schemas correspondants. Nous verrons cela par la suite.

Commencons par la validation des resources natives.

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

This time, running `kubeconform manifests.yaml` passes. To make kubeconform detect additional fields, we need to specify `--strict`:

```
kubeconform --strict manifests.yaml       

manifests.yaml - DaemonSet nginx-ds is invalid: problem validating schema. Check JSON formatting: jsonschema: '/spec' does not validate with https://raw.githubusercontent.com/yannh/kubernetes-json-schema/master/master-standalone-strict/daemonset-apps-v1.json#/properties/spec/additionalProperties: additionalProperties 'replicas' not allowed
```

## Corner cases

Comme expliqué dans l'article sur kubeval, la validation basée sur les schémas est souvent approximative. La vérification des types des propriétés fonctionne plutot bien mais la validation des valeurs associées sont moins fiables. Cela vient du fait que la logique de validation est implémentée dans du code spécifique et ne fait pas toujours partie de la définition du schéma.

Prenons l'exemple d'un label invalide:

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

Essayons de valider la resource ci dessus avec:

```bash
kubeconform --strict manifests.yaml
```

Cette fois ci kubeconform ne détecte pas le label invalide.

Un autre exemple simple est le suivant, qui définit un `Deployment` avec un nombre de replicas négatif:

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

Ici aussi, `kubeconform --strict manifests.yaml` ne détecte pas le problème alors que la resource sera rejetée par un cluster:

```
kubectl apply -f manifests.yaml

The Deployment "deploy" is invalid: spec.replicas: Invalid value: -1: must be greater than or equal to 0
```

## Target Kubernetes Version

In the case of native resources, the target version of the cluster is important, as native resources evolve regularly with the appearance of new properties, new API versions, some API versions are deprecated and then removed, etc.

Therefore, a resource considered valid given one version of Kubernetes may be considered invalid with an older version of Kubernetes.

It is possible to target a specific version of Kubernetes using the `--kubernetes-version` argument.

Prenons par exemple l'api `extensions/v1beta1` qui a été retirée de Kubernetes en v1.22:

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

La resource `Ingress` ci dessus est considérée comme valide avec Kubernetes `v1.20`:

```
kubeconform --kubernetes-version 1.20.0 --strict manifests.yaml
```

Alors que le schéma n'est plus disponible en `v1.22`:

```
kubeconform --kubernetes-version 1.22.0 --strict manifests.yaml

manifests.yaml - Ingress frontend failed validation: could not find schema for Ingress
```

## CRDs validation

Finissons par la validation des resources customs (CRDs).

Kubeconform supporte les resources customs a condition que vous puissiez lui fournir le JSON schema correspondant.

Pour reprendre l'exemple sur le [GitHub de kubeconform](https://github.com/yannh/kubeconform?tab=readme-ov-file#customresourcedefinition-crd-support), on peut utiliser [Datree's CRDs-catalog](https://github.com/datreeio/CRDs-catalog) qui recense les CRDs les plus utilisés et fournit les JSON schemas associés.


Prenons par exemple une resource `Issuer` de cert manager:

```yaml
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: test-selfsigned
  namespace: cert-manager-test
spec:
  selfSigned: {}
```

Sans préciser la localisation du schéma associé au type de resource `Issuer`, kubeconform est incapable de valider la resource:

```
kubeconform --strict manifests.yaml

manifests.yaml - Issuer test-selfsigned failed validation: could not find schema for Issuer
```

Afin de permettre a kubeconform de télécharger le JSON schema associé, on peut utiliser l'argument `--schema-location`:

```
kubeconform --schema-location 'https://raw.githubusercontent.com/datreeio/CRDs-catalog/main/{{.Group}}/{{.ResourceKind}}_{{.ResourceAPIVersion}}.json' --strict manifests.yaml
```

Cette fois-ci kubeconform est en mesure de valider la resource `Issuer` grace au schéma téléchargé depuis le repository GitHub de Datree.

Notez que l'on peut préciser l'argument `--schema-location` autant de fois que nécessaire.
Il est aussi possible de convertir une défintion de CRD soit même, tout est expliqué [ici](https://github.com/yannh/kubeconform?tab=readme-ov-file#customresourcedefinition-crd-support).

# Conclusion

En conclusion, kubeconform s'est très fortement inspiré de kubeval et a repris le flambeau pour devenir son digne successeur.

Les deux outils fonctionnent exactement de la même manière en se basant sur les JSON schema. kubeconform maintient une version a jour des schemas pour les resources natives.

Enfin kubeconform ajoute le support des resources customs, ce qui élargit grandement la portée de l'outil. Leur utilisation reste cependant assez complèxe, surtout dans le cas d'une resource custom dont le schéma n'est pas disponible publiquement sur internet.

En résumé, kubeconform est un grand pas en avant pour les utilisateurs de kubeval, un outil satisfaisant pour une utilisation sans resources customs. Il reste cependant limité dans le cas d'une utilisation intensive des CRDs.

Le prochain article étudiera un outil plus adapté a une utilisation moderne de Kubernetes avec un support plus poussé des resources customs. Stay tuned for the next episode!