1. `eval $(minikube docker-env)`
2. `docker pull moretea/k8s-viz`
3. `docker run -v $HOME/.minikube:/root/.minikube -p 9292:9292 --rm -ti moretea/k8s-viz`
4. `echo "http://$(minikube ip):9292/"` <-- visit that URL to see the k8s visualisation UI
