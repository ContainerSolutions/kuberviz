FROM ubuntu
RUN apt-get update && apt-get install -yq ruby bundler curl graphviz
RUN curl -L https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl -o /usr/bin/kubectl
RUN chmod +x /usr/bin/kubectl

RUN mkdir -p /app/
ADD ./Gemfile*  /app/
WORKDIR /app
RUN bundle install

ADD ./public/ /app/public
ADD ./views/ /app/views
ADD ./*.rb /app/
ADD ./*.ru /app/
ENTRYPOINT bundle exec rackup -o 0.0.0.0 -p 9292
