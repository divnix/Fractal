{inputs, cell}: let
    l = nixpkgs.lib // builtins;

    inherit (inputs) nixpkgs std;
    inherit (std.lib) dev;

    withCategory = category: attrset: attrset // {inherit category;};
in 
  l.mapAttrs (_: dev.mkShell) {
    default = {...}: {
      name = "Fractal Devenv";
      nixago = with std.presets.nixago; [
        treefmt
        lefthook
        editorconfig
        (conform {configData = {inherit (inputs) cells;};})
      ];
      imports = [];
      commands = [
        (withCategory "fractal" {package = nixpkgs.jq;})
        (withCategory "fractal" {package = nixpkgs.ijq;})
        (withCategory "fractal" {package = nixpkgs.yq-go;})
        (withCategory "fractal" {package = nixpkgs.python3;})
        (withCategory "fractal" {package = l.lazyDerivation {
            derivation = nixpkgs.writers.writePython3Bin "json2nix.py" {} (l.readFile ./json2nix.py);
            meta.description = "a hacky json2nix script";
        };})
        (withCategory "fractal" {package = l.lazyDerivation {
            derivation = nixpkgs.writers.writeBashBin "convert.sh" ''
              for i in *.yaml; do
                  strip=''${i%.*}
                  [ -f "$i" ] || break
                  yq e -j "$i" | python3 ./json2nix.py /dev/stdin > "$strip.nix"
              done
            '';
            meta.description = "convert all yaml files in the cwd to nix";
        };})
      ];
    };
  }

