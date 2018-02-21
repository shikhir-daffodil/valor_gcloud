#require 'googleauth'
require 'google/apis/compute_v1'
require 'net/http'

class IndexController < ApplicationController
  def index
    @project = 'valor-157707'
    @zone = 'us-central1-c'
    @name = 'apitest2'
    @compute = create_instance
  end

  def get_token
    @token = get_authorization
    @data = set_fingerprint
  end

  def get_instance_status
    @project = 'valor-157707'
    @zone = 'us-central1-c'
    @name = 'instance-2'
    @status = set_fingerprint["status"] # STOPPING, RUNNING, TERMINATED
  end

 protected

  def get_authorization # only for accessing web services from compute engine itself
    url = URI.parse('http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token')
    req = Net::HTTP::Get.new(url.to_s)
    req.add_field("Metadata-Flavor", "Google")
    begin
      res = Net::HTTP.start(url.host, url.port) {|http|
        http.request(req)
      }
      body = JSON.parse(res.body)
      return body["access_token"]
    rescue
      return "Bearer access token could not be generated."
    end
  end

  def create_instance # create an instance from an existing image
    access_token = get_authorization # Bearer Access token to access API
    url = URI.parse("https://www.googleapis.com/compute/v1/projects/#{@project}/zones/#{@zone}/instances?alt=json")
    req = Net::HTTP::Post.new(url.to_s)
    req.add_field("Authorization", "Bearer #{access_token}")
    req.add_field("Accept", "application/json")
    req.add_field("Content-Type", "application/json")
    machine_type = 'zones/us-central1-c/machineTypes/f1-micro'
    network_interfaces = ['accessConfigs' => ['type' => 'ONE_TO_ONE_NAT', '@name' => 'External NAT'],
      'network' => 'global/networks/default']
    disks = ['boot' => 'true', 'type' => 'PERSISTENT', 'autoDelete' => 'true',
      'initializeParams' => ['sourceImage' => 'global/images/independent-game']]

    post_body = {}
    post_body['name'] = @name
    post_body['machineType'] = machine_type
    post_body['networkInterfaces'] = network_interfaces
    post_body['disks'] = disks
    req.body = post_body.to_json
    begin
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      response = http.request(req)
      data = set_fingerprint
      set_tags = network_http_tags(data["tags"]["fingerprint"])
      set_metadata = set_metadata(data["metadata"]["fingerprint"])
    rescue
      raise "There was an error creating the instance"
    end
    data = set_fingerprint
    set_tags = network_http_tags(data["tags"]["fingerprint"])
    set_metadata = set_metadata(data["metadata"]["fingerprint"])
    return true
  end

  def stop_instance # POST request without body to stop the instance
    access_token = get_authorization # Bearer Access token to access API
    url = URI.parse("https://www.googleapis.com/compute/v1/projects/#{@project}/zones/#{@zone}/instances/#{@name}/stop")
    req = Net::HTTP::Post.new(url.to_s)
    req.add_field("Authorization", "Bearer #{access_token}")
    req.add_field("Accept", "application/json")
    req.add_field("Content-Type", "application/json")
    begin
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      response = http.request(req)
    rescue
      raise "There was an error stopping the instance"
    end
    return true
  end

  def start_instance # POST request without body to stop the instance
    access_token = get_authorization # Bearer Access token to access API
    url = URI.parse("https://www.googleapis.com/compute/v1/projects/#{@project}/zones/#{@zone}/instances/#{@name}/start")
    req = Net::HTTP::Post.new(url.to_s)
    req.add_field("Authorization", "Bearer #{access_token}")
    req.add_field("Accept", "application/json")
    req.add_field("Content-Type", "application/json")
    begin
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      response = http.request(req)
    rescue
      raise "There was an error starting the instance"
    end
    return true
  end

  def delete_instance # delete request to the url
    access_token = get_authorization # Bearer Access token to access API
    uri = URI("https://www.googleapis.com/compute/v1/projects/#{@project}/zones/#{@zone}/instances/#{@name}")
    begin
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      req = Net::HTTP::Delete.new(uri)
      req.add_field("Authorization", "Bearer #{access_token}")
      req.add_field("Accept", "application/json")
      res = http.request(req)
    rescue
      raise "There was an error deleting the instance"
    end
    return true
  end


  def network_http_tags(fingerprint) # used to set tags to allow http request in instance
    access_token = get_authorization # Bearer Access token to access API
    url = URI("https://www.googleapis.com/compute/v1/projects/#{@project}/zones/#{@zone}/instances/#{@name}/setTags")
    req = Net::HTTP::Post.new(url.to_s)
    req.add_field("Authorization", "Bearer #{access_token}")
    req.add_field("Accept", "application/json")
    req.add_field("Content-Type", "application/json")
    items = ['http-server']

    post_body = {}
    post_body['items'] = items
    post_body['fingerprint'] = fingerprint
    req.body = post_body.to_json
    begin
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      response = http.request(req)
    rescue
      raise "Http connection not created"
    end
    return true
  end

  def set_metadata(fingerprint) # used to set metadata to add startup script to instance and reboot
    access_token = get_authorization # Bearer Access token to access API
    url = URI("https://www.googleapis.com/compute/v1/projects/#{@project}/zones/#{@zone}/instances/#{@name}/setMetadata")
    req = Net::HTTP::Post.new(url.to_s)
    req.add_field("Authorization", "Bearer #{access_token}")
    req.add_field("Accept", "application/json")
    req.add_field("Content-Type", "application/json")
    items = ['key' => 'startup-script', 'value' => '#! /bin/bash
su daffolap
sh /home/daffolap/sidekiq.sh']

    post_body = {}
    post_body['items'] = items
    post_body['kind'] = "compute#metadata"
    post_body['fingerprint'] = fingerprint
    req.body = post_body.to_json
    begin
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      response = http.request(req)
      stop = stop_instance
      start = start_instance
    rescue
      raise "Startup script not created"
    end
    return true 
  end

  def set_fingerprint # used to get fingerprint for adding tags to the instance
    access_token = get_authorization # Bearer Access token to access API
    url = URI.parse("https://www.googleapis.com/compute/v1/projects/#{@project}/zones/#{@zone}/instances/#{@name}")
    req = Net::HTTP::Get.new(url.to_s)
    req.add_field("Authorization", "Bearer #{access_token}")
    begin
      http = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
      response = http.request(req)
      res = JSON.parse(response.body)
    rescue
      return false
    end
    return res
  end
end
