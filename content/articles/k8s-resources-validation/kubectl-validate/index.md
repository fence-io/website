---
authors:
- eddycharly
title: Validating Kubernetes resources offline - kubectl-validate review
date: 2024-05-05
tags:
- Validation
- Kubernetes
- CI
# featureImage: https://opengraph.githubassets.com/0fb34fac5b9bbfc8c22fe2e8d5025cf835fff5451d942903464a45131e8b85df/instrumenta/kubeval
series: ["Offline Kubernetes Validation"]
series_order: 3
series_opened: true
series_title: kubectl-validate review
---

Après kubeval et kubeconform, nous allons cette fois ci nous intéresser a kubectl-validate.

Ce dernier outil se distingue des précédents par son approche plus moderne qui n'utilise pas les JSON schemas.

# Introduction

Tout d'abord, je vous invite a consulter l'introduction de l'article sur kubeval qui décrit la validation hors ligne de manière générale. Bien que kubectl-validate ne s'appuie pas sur les JSON schemas, les principes généraux de la validation de resources s'appliquent aussi a l'outil.

Au lieu d'utiliser les JSON schemas, kubectl-validate se base directement sur les schemas OpenAPI de Kubernetes et utilise les mêmes mécanismes que ceux utilisés par le serveur d'api de Kubernetes.

Les auteurs a l'origine de kubectl-validate travaillent aussi sur le serveur d'api et connaissent donc parfaitement le sujet.

TODO: inclure la vidéo d'alex et stephan
https://www.youtube.com/watch?v=KaXIq8Qv77A

## Resource Schemas

Kubectl-validate works exclusively with OpenAPI v3 schemas and therefore cannot be used with Kubernetes versions before v1.23. There is an open issue to support OpenAPI v2 but it hasn't been worked on yet.

Cela étant dit, l'une des forces de l'outil est de pouvoir charger les schémas depuis plusieurs sources.
Pour les resources natives, kubectl-validate embarque directement les schémas dans le binaire de la version 1.23 a la version 1.30 de Kubernetes.

Il peut aussi aller les chercher sur le repository GitHub de Kubernetes si besoin.

On peut aussi lui fournir les schémas directement, par exemple dans le cas ou les schemas auraient été exportés depuis un cluster existant.
On peut lui fournir directement les manifestes des CRDs.
Ou bien on peut le faire pointer sur un cluster existant, il se chargera de récupérer les schémas depuis ce dernier.

Enfin, il est tout a fait possible de combiner les options ci dessus entre elles pour charger et aggréger les schémas depuis differentes sources.

# Installing kubectl-validate

Pour l'instant, l'installation de kubectl-validate peut se faire soit en téléchargeant le binaire depuis la page de release, ou bien en compilant le binaire avec la suite golang.

Il n'y a pas encore d'image Docker disponible, et il n'est quasiment pas disponible au travers des gestionnaires de paquets classiques.

De plus, le cycle de release reste assez flou et des correctifs importants présents sur la branche principale n'ont pas encore été officiellement releasés.

Pour cet article j'utiliserai donc une version compilée manuellement a partir de la branche principale.

```bash
go install sigs.k8s.io/kubectl-validate@latest
```

# Validation with kubectl-validate

Again, let’s start by validating native resources.

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

