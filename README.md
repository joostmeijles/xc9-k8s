# XC9 + K8S + AKS = Bingo!
This repository investigates the possibilities of using Azure Kubernetes Service (AKS) for running Sitecore eXperience Commerce 9 (XC9).

Kubernetes (K8S) introduces, on top of Docker, a number of new concepts: https://kubernetes.io/docs/concepts/

Running Windows containers on AKS is currently in preview. Microsoft offers a guide to get an example Windows application running: Follow https://docs.microsoft.com/en-us/azure/aks/windows-container-cli 

Not that you can currently not run Kubernetes & Windows containers locally as Docker Desktop has only Kubernetes support for Linux containers (hopefully this will change in the future with the official release of WSL 2).

> DISCLAIMER
> This repository provides a Sitecore XC 9 AKS setup for *study* purposes and is not to be meant to be used in production.

Getting up and running with Sitecore XC 9, Kubernetes, and Azure Kubernetes Service is split up in two parts:
- [Creating a Kubernetes cluster in AKS](./cluster/README.md)
- [Preparing and running XC 9 in AKS](./xc9/README.md)

After reading and applying these parts you will have a basic understanding of how to deploy Sitecore XC in AKS.
