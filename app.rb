require "sinatra"
require "sinatra/contrib"
require "net/http"
require "uri"
require "json"
require "open3"

$namespace = "default"

kubectl_cfg = YAML.load File.read(File.expand_path("~/.kube/config"))
current_context = kubectl_cfg["current-context"]

raise("erm, nope") if current_context != "minikube"

cluster_conf = kubectl_cfg["clusters"].select { |c| c["name"] == current_context }.first["cluster"]
$api_server_prefix = cluster_conf["server"]
$api_server_ca = cluster_conf["certificate-authority"]

TOKEN=`kubectl describe secret $(kubectl get secrets | grep default | cut -f1 -d ' ') | grep -E '^token' | cut -f2 -d':' | tr -d '\\t'`.chomp

def request_api(path)
 uri = URI.parse($api_server_prefix + path)
 req = Net::HTTP::Get.new(uri.path)
 req.add_field("Authorization", "Bearer #{TOKEN}")
 res = Net::HTTP.start(uri.host, uri.port, use_ssl: (uri.scheme == 'https'), ca_file: $api_server_ca) do |http|
     http.request(req)
 end
 if res.code != "200"
   raise "got status code #{res.code}"
 end
 return JSON.load(res.body)
end

module Matchable
  def matches?(selector)
    return false if selector.keys.length == 0

    selector.each do |key, value|
      return false if @labels[key] != value
    end

    true
  end
end

class Pod
  include Matchable

  attr_reader :id, :name, :labels

  def initialize(api, id)
    @id = "pod_#{id}"
    @name = api["metadata"]["name"]
    @labels = api["metadata"]["labels"]
  end

  def to_dot
    "#{@id} [label=\"#{@name}\", shape=rect];"
  end

end

class ReplicaSet
  include Matchable
  attr_reader :id, :name, :selector

  def initialize(api, id)
    @id = "replica_set_#{id}"
    @name = api["metadata"]["name"]
    @labels = api["metadata"]["labels"]
    @selector = api["spec"]["selector"]
  end

  def nodes_to_dot
    "#{@id} [label=\"#{@name}\", shape=rect, style=filled, fillcolor=red];"
  end

  def edges_to_dot(pods:)
    child_pods = pods.select { |pod| pod.matches?(self.selector["matchLabels"]) }
    
    lines = []
    child_pods.each do |child_pod|
      lines.push "#{@id} -> #{child_pod.id};"
    end
    lines.join("\n")
  end

  def to_dot(pods:)
    nodes_to_dot + edges_to_dot(pods:pods)
  end
end

class StatefulSet
  include Matchable
  attr_reader :id, :name, :selector

  def initialize(api, id)
    @id = "statefulset#{id}"
    @name = api["metadata"]["name"]
    @labels = api["metadata"]["labels"]
    @selector = api["spec"]["selector"]
  end

  def nodes_to_dot
    "#{@id} [label=\"#{@name}\", shape=rect, style=filled, fillcolor=orange,tooltip=\"statefulset\"];"
  end

  def edges_to_dot(pods:)
    child_pods = pods.select { |pod| pod.matches?(self.selector["matchLabels"]) }
    
    lines = []
    child_pods.each do |child_pod|
      lines.push "#{@id} -> #{child_pod.id};"
    end
    lines.join("\n")
  end

  def to_dot(pods:)
    nodes_to_dot + edges_to_dot(pods:pods)
  end
end

class ReplicationController
  include Matchable
  attr_reader :id, :name, :selector

  def initialize(api, id)
    @id = "replication_controller#{id}"
    @name = api["metadata"]["name"]
    @labels = api["metadata"]["labels"]
    @selector = api["spec"]["selector"]
  end

  def nodes_to_dot
    "#{@id} [label=\"#{@name}\", shape=rect, style=filled, fillcolor=red];"
  end

  def edges_to_dot(pods:)
    child_pods = pods.select { |pod| pod.matches?(self.selector) }
    
    lines = []
    child_pods.each do |child_pod|
      lines.push "#{@id} -> #{child_pod.id};"
    end
    lines.join("\n")
  end

  def to_dot(pods:)
    nodes_to_dot + edges_to_dot(pods:pods)
  end
end

class Service
  attr_reader :id, :name, :selector

  def initialize(api, id)
    @id = "service#{id}"
    @name = api["metadata"]["name"]
    @labels = api["metadata"]["labels"]
    @selector = api["spec"]["selector"]
  end

  def nodes_to_dot
    "#{@id} [label=\"#{@name}\", shape=rect, style=filled, fillcolor=green];"
  end

  def edges_to_dot(pods:)
    return "" if self.selector.nil?
    child_pods = pods.select { |pod| pod.matches?(self.selector) }
    
    lines = []
    child_pods.each do |child_pod|
      lines.push "#{child_pod.id} -> #{@id};"
    end
    lines.join("\n")
  end

  def to_dot(pods:)
    nodes_to_dot + edges_to_dot(pods:pods)
  end
end

class Deployment
  attr_reader :id, :name, :selector

  def initialize(api, id)
    @id = "deployment#{id}"
    @name = api["metadata"]["name"]
    @labels = api["metadata"]["labels"]
    @selector = api["spec"]["selector"]
  end

  def nodes_to_dot
    "#{@id} [label=\"#{@name}\", shape=rect, style=filled, fillcolor=yellow];"
  end

  def edges_to_dot(replica_sets)
    child_sets = replica_sets.select { |rs| rs.matches?(self.selector["matchLabels"]) }
    
    lines = []
    child_sets.each do |child|
      lines.push "#{@id} -> #{child.id}"
    end
    lines.join("\n")
  end

  def to_dot(replica_sets:)
    nodes_to_dot + edges_to_dot(replica_sets)
  end
end

class Model
  def self.fetch
    pods = request_api("/api/v1/namespaces/"+$namespace+"/pods")["items"] || []
    rsets= request_api("/apis/extensions/v1beta1/namespaces/"+$namespace+"/replicasets")["items"] || []
    rcs = request_api("/api/v1/namespaces/"+$namespace+"/replicationcontrollers")["items"] || []
    svcs = request_api("/api/v1/namespaces/"+$namespace+"/services")["items"] || []
    statefulsets = request_api("/apis/apps/v1beta1/namespaces/"+$namespace+"/statefulsets")["items"] || []
    deployments = request_api("/apis/extensions/v1beta1/namespaces/"+$namespace+"/deployments")["items"] || []


    pods = pods.each_with_index.map {|x,i| Pod.new x, i }
    rsets = rsets.each_with_index.map {|x,i| ReplicaSet.new x, i }
    rcs = rcs.each_with_index.map {|x,i| ReplicationController.new x, i }
    svcs = svcs.each_with_index.map {|x,i| Service.new x, i }
    statefulsets = statefulsets.each_with_index.map {|x,i| StatefulSet.new x, i }
    deployments = deployments.each_with_index.map {|x,i| Deployment.new x,i  }

    Model.new(pods: pods,
      replication_controllers: rcs,
      replica_sets: rsets,
      services: svcs,
      statefulsets: statefulsets,
      deployments: deployments
    )
  end

  def initialize(pods:, replication_controllers:, replica_sets:, statefulsets:, services:, deployments:)
    @pods = pods
    @replication_controllers = replication_controllers
    @replica_sets = replica_sets
    @services = services
    @deployments = deployments
    @statefulsets = statefulsets
  end

  def to_dot
    lines =  ["digraph k8s {"]

    @pods.each { |pod| lines.push pod.to_dot }
    @replication_controllers.each {|rc| lines.push rc.to_dot(pods: @pods) }
    @replica_sets.each {|rs| lines.push rs.to_dot(pods: @pods) }
    @services.each {|s| lines.push s.to_dot(pods: @pods) }
    @deployments.each {|d| lines.push d.to_dot(replica_sets: @replica_sets) }
    @statefulsets.each {|sfs| lines.push sfs.to_dot(pods: @pods) }

    lines.push("}")
    lines.join("\n")
  end

  def to_svg
    stdout, stderr, status = Open3.capture3("dot -Tsvg", stdin_data: self.to_dot)
    if status.success?
      stdout
    else
      puts self.to_dot
      raise({ stdout: stdout, stderr: stderr, status: status}.inspect)
    end
  end

end

class K8sViz < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  get "/" do
    erb :index
  end

  get "/graph.svg" do
    content_type "image/svg+xml"
    Model.fetch.to_svg
  end

  get "/graph.dot" do
    Model.fetch.to_dot
  end
end
