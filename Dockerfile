FROM nixos/nix
RUN mkdir -p /app/
ADD ./Gemfile*  /app/
ADD ./*.nix /app/
WORKDIR /app
RUN nix-build shell.nix

ADD ./public/ /app/public
ADD ./views/ /app/views
ADD ./*.rb /app/
ADD ./*.ru /app/
ADD ./docker/kube-config /root/.kube/config
ENTRYPOINT nix-shell --run "rackup -o 0.0.0.0 -p 9292"
