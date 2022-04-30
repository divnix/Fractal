{ inputs, ... }: let
    inherit (inputs) self;
    base = inputs.xnlib.lib;
in base.extend (lib: super: let
    inherit (builtins) toJSON fromJSON toPath readFile readDir replaceStrings pathExists;
    inherit (lib) attrByPath attrNames optional flatten flip head elem length filterAttrs mapAttrs mapAttrs' listToAttrs nameValuePair fold filter last drop
        recursiveMerge splitString concatStringsSep recImportDirs mkProfileAttrs evalModules;

    # todo: hack? should xnlib pass this itself?
    pkgs = import inputs.xnlib.inputs.nixpkgs {
        system = "x86_64-linux";
    };

    f = path: import path {
        inherit inputs lib;
    };
in super // {
    kube = rec {
        generators = f ./generators.nix;
        inherit (generators) makeStdFlake;

        # TODO: move the stuff below into their own individual files
        friendlyPathName = path: let
            f = last (splitString "/" path);
        in concatStringsSep "-" (drop 1 (splitString "-" f));

        componentDefaultFile = dir: let
            allowed = ["main.jsonnet" "kustomization.yaml"];
            files = attrNames (filterAttrs (n: v: v == "regular") (readDir dir));
            results = filter (f: elem f allowed) files;
        in if length results > 0 then head results else null;

        # Special module importer to support automatic component generation
        # default.nix will *always* take priority over any other file that produces resources!
        # after that, the order is jsonnet -> kustomize
        componentModules = dir: type: let
            substituter = readFile ./substituter.nix;

            folders = attrNames (filterAttrs (n: v: v == "directory") (readDir dir));
            results = if !(pathExists dir) then [] else map (m: let
                path = dir + "/${m}";
                default = path + "/default.nix";
            in if pathExists default then import default else let
                file = componentDefaultFile path;
            in if file == null then null else
                import ./substituter.nix {
                    inherit type path file;
                    name = m;
                }
            ) folders;
        in filter (m: m != null) results;

        clusterConfiguration = {
            configuration,
            extraModules ? [],
            extraSpecialArgs ? {}
        }@args: let
            module = evalModules {
                # !!! OF COURSE you can pass attrs in here
                # !!! I don't know why I was so stupid to require the substituter whatever
                modules = [ configuration ] ++ extraModules ++ self.kube.modules;
                specialArgs = extraSpecialArgs;
            };
        in rec {
            inherit (module) options config;

            # output the compiled manifests
            manifests = {
                crds = compileManifests config.resources.crds;
                features = compileManifests (defaultNamespaces config.cluster.namespaces.features config.resources.features);
                operators = compileManifests (defaultNamespaces config.cluster.namespaces.operators config.resources.operators);
                services = compileManifests (defaultNamespaces config.cluster.namespaces.services config.resources.services);
            };
        };

        clusterConfigurations = dir: params: recImportDirs {
            inherit dir;
            _import = n: clusterConfiguration ({
                configuration = import (dir + "/${n}");
            } // params);
        };

        # Sets default namespaces on an attribute set of resources
        defaultNamespaces = namespace: attrs: mapAttrs (_: v: if
            ((attrByPath ["metadata" "namespace"] null v) != null)
        then v else v // { metadata = v.metadata // { inherit namespace; }; }) attrs;

        resourceId = resource: let
            # replace slashes with underscores
            rep = replaceStrings ["/"] ["_"];
            seek = p: rep (attrByPath p "_" resource);

            group = seek ["apiVersion"];
            kind = resource.kind;
            namespace = seek ["metadata" "namespace"];
            name = resource.metadata.name;
        in "${group}/${kind}/${namespace}/${name}";

        # creates unique IDs for Kubernetes resources
        uniqueResources = mapAttrs' (_: v: nameValuePair (resourceId v) v);

        # import unique resources from a .nix file
        uniqueResourcesFromFile = inputs: file: let
            data = import file inputs;
        in listToAttrs (map (r: nameValuePair (resourceId r) r)) data;

        # import unique resources from multiple .nix files
        uniqueResourcesFromFiles = inputs: files:
            recursiveMerge (map (f: uniqueResourcesFromFile inputs f) files);

        compileManifests = attrs: let
            source = pkgs.writeText "resources.json" (toJSON attrs);
            result = pkgs.runCommand "kube-compile" {
                preferLocalBuild = true;
                allowSubstitutes = false;
            } "${pkgs.yq-go}/bin/yq e -P '.[] | splitDoc' ${source} > $out";
        in readFile result;

        # Compiles Jsonnet code located at the specified path
        compileJsonnet = path: inputs: let
            f = pkgs.writeText "inputs.json" (toJSON inputs);

            # -J ${dirOf path} is required here because ${path} only brings that specific file into the closure
            result = pkgs.runCommand "jsonnet-build-${friendlyPathName path}" {
                preferLocalBuild = true;
                allowSubstitutes = false;
            } "${pkgs.go-jsonnet}/bin/jsonnet ${path} -J ${dirOf path} -J ${./../support/jsonnet} --ext-code-file inputs=${f} -o $out";
        in uniqueResources (fromJSON (readFile result));

        # Builds a Kustomization and returns Kubernetes objects
        compileKustomization = path: let
            result = pkgs.runCommand "kustomize-build-${friendlyPathName path}" {
                preferLocalBuild = true;
                allowSubstitutes = false;
            } "${pkgs.kustomize}/bin/kustomize build ${path} | ${pkgs.yq-go}/bin/yq ea -o=json '[.]' - > $out";
        in listToAttrs (map (r: nameValuePair (resourceId r) r) (fromJSON (readFile result)));
    };
})
