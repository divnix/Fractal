# Fractal Configuration Interface

In this folder you can see the entire public Fractal configuration interface.

- `options/cluster.nix` &mdash; implements the cluster-level configuration options
- `options/component.nix` &mdash; implements the component-level configuration options
  Component-level configurations will be dynamically loaded to the cluster level.
  For example you can switch off a component via eithe `<type:operators|features|services>.<name>.enable = false;` or, if a component default namespace was set, `<type:operators|features|services>.<namespace>.<name>.enable = false;`.
