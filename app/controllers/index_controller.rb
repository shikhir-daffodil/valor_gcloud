#require 'googleauth'
require 'google/apis/compute_v1'
require 'net/http'

class IndexController < ApplicationController
  def index
		@compute = create_instance_two
		abort(@compute.inspect.to_s)
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
# 			scopes =  ['https://www.googleapis.com/auth/cloud-platform',
#           'https://www.googleapis.com/auth/compute']
#			authorization = Google::Auth.get_application_default(scopes)
#			return authorization
      raise "Bearer access token could not be generated."
 		 end
 	end

 	def create_instance
 		# compute = Google::Apis::ComputeV1::ComputeService.new
 		# # compute.instances.insert
 		# return compute
 		service = Google::Apis::ComputeV1::ComputeService.new

		service.authorization = get_authorization

		# Project ID for this request.
		project = 'valor-157707'  # TODO: Update placeholder value.

		# The name of the zone for this request.
		zone = 'us-central1-c'  # TODO: Update placeholder value.

		# TODO: Assign values to desired members of `request_body`:
		request_body = Google::Apis::ComputeV1::Instance.new
		request_body.name = "api-test2"
		request_body.machine_type = "zones/us-central1-c/machineTypes/f1-micro"
		request_body.network_interfaces = ["accessConfigs" => ["type" => "ONE_TO_ONE_NAT", "name" => "External NAT"],
		  "network" => "global/networks/default"]
		request_body.disks = ["boot" => "true", "type" => "PERSISTENT", "autoDelete" => "true",
			"initializeParams" => ["sourceImage" => "global/images/independent-game"]]

		response = service.insert_instance(project, zone, request_body)

		# TODO: Change code below to process the `response` object:
		return response.to_json
 	end

 	def create_instance_two
    project = 'valor-157707'
    zone = 'us-central1-c'
		access_token = get_authorization # Bearer Access token to access API
    url = URI.parse("https://www.googleapis.com/compute/v1/projects/#{project}/zones/#{zone}/instances?alt=json")
    req = Net::HTTP::Post.new(url.to_s)
    req.add_field("Authorization", "Bearer #{access_token}")
    req.add_field("Accept", "application/json")
    req.add_field("Content-Type", "application/json")
		name = "api-test2"
		machine_type = "zones/us-central1-c/machineTypes/f1-micro"
		network_interfaces = ["accessConfigs" => ["type" => "ONE_TO_ONE_NAT", "name" => "External NAT"],
		  "network" => "global/networks/default"]
		disks = ["boot" => "true", "type" => "PERSISTENT", "autoDelete" => "true",
			"initializeParams" => ["sourceImage" => "global/images/independent-game"]]

    post_body = {}
    post_body["name"] = name
    post_body["machine_type"] = machine_type
    post_body["network_interfaces"] = network_interfaces
    post_body["disks"] = disks
    req.body = post_body.join
    res = Net::HTTP.start(url.host, url.port) {|http|
      http.request(req)
    }
    abort(res.inspect.to_s)
	end
end