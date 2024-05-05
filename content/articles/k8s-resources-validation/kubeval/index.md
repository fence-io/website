Dans cet article nous allons parler de validation de définitions de resources kubernetes a l'aide de l'outil kubeval.

Avant de commencer, quelque remarques sur l'outil testé:
- il n'est plus maintenu et l'auteur conseille de migrer vers kubeconform
- nous étudierons kubeconform dans un prochain article

# Introduction

La validation des resources Kubernetes est utile pour détecter les resources non conformes avant de les appliquer a un cluster.
Le cas d'utilisation le plus courant est d'effectuer la validation lors de la CI pour valider (ou invalider) la qualité d'une pull request.

Dans ce cas précis on ne dispose généralement pas d'un cluster disponible et validation doit donc s'effectuer hors ligne.

L'outil doit donc pouvoir fonctionner de manière autonome et valider (ou invalider) les manifests fournis en entrée.

# La validation coté Kubernetes

La validation au sein d'un cluster Kubernetes s'effectue de différente manière en fonction des types de resources utilisées.

Dans le cas d'une resource native Kubernetes (`ConfigMap`, `Deployment`, `Pod`, etc...) la validation est faite par un code dédié. La logique de validation est donc difficilement exploitable, elle n'est pas exprimée de manière déclarative.

Vient ensuite le cas des resources customs décrites a l'aide de CRDs. Ce type de resources ne sont pas natives et doivent respecter un schéma plus ou moins précis. Ce schéma est utilisé par Kubernetes pour valider une resource qui lui est soumise.

Enfin, il est aussi possible de venir enrichir la logique de validation en ajoutant des webhooks invoqués par le serveur d'api Kubenetes au moment de l'admission des resources.

## Les schemas de resources

Les schémas des resources natives ou customs sont exprimés a l'aide d'OpenAPI v2 (ou v3 pour les versions plus récentes de Kubernetes). Ces schémas sont plus ou moins précis dans le cas des resources natives, la logique de validation étant implémentée dans du code dédié.

Ce sont ces schémas qui sont utilisés par la plupart des outils de validation de resources pour valider (ou non) les resources proposées.

## Les webhooks de validation

Jusqu'a récemment les webhooks de validation étaient des services classiques, internes ou externes au cluster, invoqués par le serveur d'api lors de l'admission d'une resource.

Ces webhooks pouvant implémenter une logique totalement personnalisée il est généralement exclut qu'un outil de validation puisse reproduire la logique embarquée dans ces différents services.

Récemment l'introdution de CEL et des politiques de validation ont permis de programmer le comportement du serveur d'api de manière déclarative. Les outils de validation sont théoriquement en mesure d'appliquer les mêmes politiques de validation que le serveur d'api.

# Installation de kubeval

La documentation du projet kubeval propose d'installer le binaire directement ou a l'aide d'un gestionnaire de paquets, ou de l'utiliser au travers une image Docker.

Pour cet article nous utiliserons l'image docker.

# Validation avec kubeval

First, let's note that kubeval [does not support validation of CRDs](https://www.kubeval.com/#crds).
The recommended workaround is to exclude custom (unknown) resources.


Let's try to validate the simple (yet invalid) manifest below:

```yaml
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: nginx-ds
spec:
  # no replicas field exist on DaemonSet
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

## Version de Kubernetes cible

Dans le cas de resources natives, la version cible du cluster est importante, les reosurces natives évoluent régulièrement avec l'apparition de nouvelles propriétés, de nouvelles version d'api, certaines versions d'api sont dépréciées puis supprimées, etc...

Il est possible de cibler une version précise de Kubernetes a l'aide de l'argument `-v`. Malheureusement l'outil s'appuie sur les schémas publiés sur le site https://kubernetesjsonschema.dev qui s'est arrété a la version 1.18 de Kubernetes.

# Conclusion

Il semble assez peu pertinent de pousser l'étude de kubeval très loin. Il est évident que l'outil est ancien, il n'est plus maintenu, a au moins 10 versions de Kubernetes de retard et est donc devenu obsolète.

Il reste tout de même le premier outil ayant popularisé la validation hors ligne des resources Kubernetes et il méritait d'être cité. Nous verrons d'autres outils plus modernes dans les prochains articles.
