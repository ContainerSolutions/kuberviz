# Prototype kubernetes visualization tool

## Demo
[See this video](https://maarten-hoogendoorn.nl/cs/chef/02-03-2017/phase02-redis-viz.mkv)

## Running it

At the moment, only minikube is supported. You need to have `kubectl` in your path.
Only tested with kubernetes / kubectl 1.5.

1. Start minikube. Make sure that minikube is your current kubectl context.
2. Install Nix (`curl https://nixos.org/nix/install | sh`, it will only write files to `/nix`, no uninstaller is needed; just kill `/nix`)
3. Run `./run.sh`
