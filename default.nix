with (import <nixpkgs> {});
let
  env = bundlerEnv {
    name = "k8s-viz-env";
    inherit ruby;
    gemfile = ./Gemfile;
    lockfile = ./Gemfile.lock;
    gemset = ./gemset.nix;
  };
in stdenv.mkDerivation {
   name = "k8s-viz";
   buildInputs = [env ruby graphviz kubernetes];
}
