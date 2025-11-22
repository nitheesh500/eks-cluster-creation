eksctl --> AWS command line tool to create and manage EKS cluster

1. create one linux server as workstation
2. install docker to build images
3. run aws configure to provide authentication
4. install eksctl to create and manage EKS cluster
5. install kubectl to work with eks cluster

ondemand, spot and reserved
ondemand --> creating server on the spot, high cost
reserved --> cost is less because you are reserving for longterm
spot --> 70-90% discount hardware available now...when our customers require we will take back your hardware with 2min notice.

SPOT instances
================
eksctl create cluster --config-file=eks.yaml

kubectl get nodes --> shows the nodes

everything in kubernetes is called as resource/object

namespace --> isolated project space where you can create and control resources to your project

default namespace is created along with cluster creation

kubectl get namespace

kind: <kind-of-resource-you-are-creating>
apiVersion: v1
metadata:
	name: <resource-name-you-want>
spec:

pod
======
docker --> image --> container
k8 --> image --> pod

container vs pod
=================
pod is the smallest deployable unit in k8. pod can have multiple containers 1 or many
all containers in pod share the same IP and storage
multiple containers are useful in few applications like shipping logs through sidecars


eksctl delete cluster --config-file=eks.yaml