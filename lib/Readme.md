# Fractal Nix Library

Fractal's nix library is split in:

- `utils` &mdash; some share utility functions
- `builders` &mdash; can process and load raw data from crds, helm charts, jsonnet & kustomize
- `generators` &mdash; generate validated fractal configuration from specific folder layouts
- `validators` &mdash; validates manifests against crd schemas and the k8s api of the current apiversion

## Getting Started

The most important function is `generators.makeStdFlake { inherit inputs; }` which consumes on the following repo structure (all optional):

```console
./components
./clusters
./crds
./crds/valitation
./modules
./helm.json
```

## TODO: good function docstrings
