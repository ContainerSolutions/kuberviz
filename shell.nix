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
  propagatedBuildInputs = [env ruby graphviz kubernetes];
  src = ./.;
  buildCommand = ''
    mkdir -p $out
    cp -r ${src} $out
  '';
}
