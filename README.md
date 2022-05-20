# Fractal

![Fractal Logo](logo.png)

Fractal is an experimental Nix-based framework for declarative configuration of Kubernetes clusters, used at Arctarus for configuration of infrastructure clusters and customer virtual clusters. Fractal makes use of [XNLib](https://github.com/ArctarusLimited/xnlib) as an extended version of the Nix standard library.

## Motivation

Fractal was built out of frustration at no existing good solution existing to manage massive and elaborate Kubernetes clusters with bleeding-edge experimental infrastructure - no matter whether they're bare metal or cloud.

The features we're aiming to implement:
- Hermetic, reproducible configuration
- Result caching for long-running builds
- Fast edit-compile-validate-deploy iterative loop
- Maximum control over building and overriding components
- GitOps support (FluxCD, ArgoCD, etc.)

## Architecture

Fractal defines Kubernetes *clusters*, configuration for which are built by a collection of Nix modules. Modules that represent an abstractable part of a cluster are referred to as *components*.

A typical Fractal repo consists of an opinionated directory structure:
- `clusters` define a subfolder per Kubernetes cluster, which lets you define important information, like the cluster name and DNS address
- `components` define the components that will be present in your cluster, these are typically seperated into three groups that are deployed sequentially:
    - `operators`, cluster operators that may be responsible for deploying features or services
    - `features`, cluster-wide infrastructure that supports services
    - `services`, the applications you run on top of your cluster
- `modules` define generic Nix modules that are imported and used to implement custom logic; you can, for example, define additional configuration for your clusters here
- `support` contains support files for build systems that are not Nix-related; for example, Jsonnet or Helm
