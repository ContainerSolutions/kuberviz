docker run \
  -v $HOME/.minikube:/root/.minikube \
  -p 9292:9292 \
  --rm -ti moretea/k8s-viz
