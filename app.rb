require "sinatra"
require "sinatra/contrib"
require "net/http"
require "uri"
require "json"
require "open3"

$namespace = "default"


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

  attr_reader :uid, :id, :name, :labels

  def initialize(api)
    @uid = api["metadata"]["uid"]
    @id = "pod_#{@uid.gsub("-","_")}"
    @name = api["metadata"]["name"]
    @labels = api["metadata"]["labels"]
    @phase = api["status"]["phase"]
  end


  def phase_color
    case @phase
    when "Pending" then "beige"
    when "Running" then "palegreen"
    when "Succeeded" then "palegreen"
    when "Failed" then "indianred"
    when "Unknownn" then "silver"
    end
  end

  def to_dot
    "#{@id} [id=\"#{@id}\", label=\"#{@name}\", shape=rect, style=filled, fillcolor=#{phase_color}];"
  end

  def to_h
    {
      uid: @uid,
      name: name,
      labels: labels,
    }
  end
end

class ReplicaSet
  include Matchable
  attr_reader :uid, :id, :name, :selector

  def initialize(api)
    @uid = api["metadata"]["uid"]
    @id = "replicaset_#{@uid.gsub("-","_")}"
    @name = api["metadata"]["name"]
    @labels = api["metadata"]["labels"]
    @selector = api["spec"]["selector"]
  end

  def nodes_to_dot
    "#{@id} [id=\"#{@id}\", label=\"#{@name}\", shape=house, style=filled, fillcolor=wheat];"
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

  def to_h(pods:)
    child_pods = pods.select { |pod| pod.matches?(self.selector["matchLabels"]) }
    {
      uid: @uid,
      pods: child_pods.map(&:to_h),
      labels: @labels,
      selector: @selector
    }
  end
end

class StatefulSet
  include Matchable
  attr_reader :uid, :id, :name, :selector

  def initialize(api)
    @uid = api["metadata"]["uid"]
    @id = "statefulset_#{@uid.gsub("-","_")}"
    @name = api["metadata"]["name"]
    @labels = api["metadata"]["labels"]
    @selector = api["spec"]["selector"]
  end

  def nodes_to_dot
    "#{@id} [id=\"#{@id}\", label=\"#{@name}\", shape=triangle, style=filled, fillcolor=wheat,tooltip=\"statefulset\"];"
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

  def to_h(pods:)
    child_pods = pods.select { |pod| pod.matches?(self.selector["matchLabels"]) }
    {
      uid: @uid,
      pods: child_pods.map(&:to_h),
      labels: @labels,
      selector: @selector
    }
  end
end

class ReplicationController
  include Matchable
  attr_reader :uid, :id, :name, :selector

  def initialize(api)
    @uid = api["metadata"]["uid"]
    @id = "replication_controller_#{@uid}"
    @name = api["metadata"]["name"]
    @labels = api["metadata"]["labels"]
    @selector = api["spec"]["selector"]
  end

  def nodes_to_dot
    "#{@id} [id=\"#{@id}\", label=\"#{@name}\", shape=house, style=filled, fillcolor=red];"
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

  def to_h(pods:)
    child_pods = pods.select { |pod| pod.matches?(self.selector) }
    {
      uid: @uid,
      pods: child_pods.map(&:to_h),
      labels: @labels,
      selector: @selector
    }
  end
end

class Service
  attr_reader :id, :name, :selector

  def initialize(api)
    @uid = api["metadata"]["uid"]
    @id = "service_#{@uid.gsub("-","_")}"
    @name = api["metadata"]["name"]
    @labels = api["metadata"]["labels"]
    @selector = api["spec"]["selector"]
  end

  def nodes_to_dot
    "#{@id} [id=\"#{@id}\", label=\"#{@name}\", shape=egg, style=filled, fillcolor=lightpink];"
  end

  def edges_to_dot(pods:)
    return "" if self.selector.nil?
    child_pods = pods.select { |pod| pod.matches?(self.selector) }
    
    lines = []
    child_pods.each do |child_pod|
      lines.push "#{child_pod.id} -> #{@id} [tailport=s];"
    end
    lines.join("\n")
  end

  def to_dot(pods:)
    nodes_to_dot + edges_to_dot(pods:pods)
  end

  def to_h(pods:)
    child_pods = if self.selector.nil? 
                 then [] 
                 else pods.select { |pod| pod.matches?(self.selector) }
                 end
    {
      uid: @uid,
      pods: child_pods.map(&:to_h),
      labels: @labels,
      selector: @selector
    }
  end
end

class Deployment
  attr_reader :id, :name, :selector

  def initialize(api)
    @uid = api["metadata"]["uid"]
    @id = "deployment_#{@uid.gsub("-","_")}"
    @name = api["metadata"]["name"]
    @labels = api["metadata"]["labels"]
    @selector = api["spec"]["selector"]
  end

  def nodes_to_dot
    "#{@id} [id=\"#{@id}\", label=\"#{@name}\", shape=component, style=filled, fillcolor=skyblue];"
  end

  def edges_to_dot(replica_sets)
    child_sets = replica_sets.select { |rs| rs.matches?(self.selector["matchLabels"]) }
    
    lines = []
    child_sets.each do |child|
      lines.push "#{@id} -> #{child.id} [tailport=s];"
    end
    lines.join("\n")
  end

  def to_dot(replica_sets:)
    nodes_to_dot + edges_to_dot(replica_sets)
  end

  def to_h(replica_sets:)
    child_sets = replica_sets.select { |rs| rs.matches?(self.selector["matchLabels"]) }
    {
      uid: @uid,
      child_sets_uids: child_sets.map { |set| set.uid },
      labels: @labels,
      selector: @selector
    }
  end
end

def list_resources kind
  stdout, stderr, status = Open3.capture3("kubectl get -o json #{kind}")

  if status.exitstatus== 0
    JSON.load(stdout)["items"]
  else
    puts "Failed to list #{kind}"
    puts stderr
    puts status.inspect
    nil
  end
end

class Model
  def self.fetch
    pods = list_resources("pods") || []
    rsets = list_resources("replicasets") || []
    rcs = list_resources("replicationcontrollers") || []
    svcs = list_resources("services") || []
    statefulsets = list_resources("statefulsets") || []
    deployments = list_resources("deployments") || []

    pods = pods.each_with_index.map {|x,i| Pod.new x }
    rsets = rsets.each_with_index.map {|x,i| ReplicaSet.new x }
    rcs = rcs.each_with_index.map {|x,i| ReplicationController.new x}
    svcs = svcs.each_with_index.map {|x,i| Service.new x }
    statefulsets = statefulsets.each_with_index.map {|x,i| StatefulSet.new x }
    deployments = deployments.each_with_index.map {|x,i| Deployment.new x }

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
    lines =  ["digraph k8s {", "ranksep=1.2; node[fontsize=15]; "]


    @pods.each { |pod| lines.push pod.to_dot }
    @replication_controllers.each {|rc| lines.push rc.to_dot(pods: @pods) }
    @replica_sets.each {|rs| lines.push rs.to_dot(pods: @pods) }
    @services.each {|s| lines.push s.to_dot(pods: @pods) }
    @deployments.each {|d| lines.push d.to_dot(replica_sets: @replica_sets) }
    @statefulsets.each {|sfs| lines.push sfs.to_dot(pods: @pods) }

    lines.push("}")
    lines.join("\n")
  end

  def to_json
    result = {
      pods: @pods.map { |pod| pod.to_h },
      replication_controllers: @replication_controllers.map {|rc| lines.push rc.to_h(pods: @pods) },
      replica_sets: @replica_sets.map {|rs| rs.to_h(pods: @pods) },
      services: @services.map {|s| s.to_h(pods: @pods) },
      deployments: @deployments.map {|d| d.to_h(replica_sets: @replica_sets) },
      statefulsets: @statefulsets.map {|sfs| sfs.to_h(pods: @pods) }
    }
    JSON.pretty_generate(result)
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

  get "/graph.json" do
    Model.fetch.to_json
  end

  post "/delete_pod" do
    system("kubectl delete pod #{params["name"]}")

    "ok"
  end
end
