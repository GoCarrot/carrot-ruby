# Carrot -- Copyright (C) 2012 Carrot Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'base64'
require 'digest'
require 'json'
require 'net/http'
require 'cgi'

class Carrot
  attr_accessor :app_id, :app_secret, :uuid, :hostname

  def initialize(app_id, app_secret, uuid = nil, hostname = 'gocarrot.com')
    @app_id = app_id
    @app_secret = app_secret
    @uuid = uuid
    @hostname = hostname
  end

  def validate_user(uuid = @uuid)
    @uuid = uuid
    http = Net::HTTP.new @hostname, 443
    http.use_ssl = true
    request = Net::HTTP::Get.new "/games/#{@app_id}/users.json?id=#{CGI::escape(uuid.to_s)}"
    response = http.request(request)
    case response
    when Net::HTTPSuccess       # User has fully-authorized app
      return :authorized
    when Net::HTTPUnauthorized  # Read-only permissions
      return :read_only
    when Net::HTTPClientError   # User has not been created
      return :not_created
    else
      puts response.body
    end
    return :unknown
  end

  def create_user(access_token, uuid = @uuid)
    http = Net::HTTP.new @hostname, 443
    http.use_ssl = true

    request = Net::HTTP::Post.new "/games/#{@app_id}/users.json"
    request.set_form_data({'access_token' => access_token, 'api_key' => @uuid})
    response = http.request(request)
    case response
    when Net::HTTPSuccess       # User created
      return :authorized
    when Net::HTTPUnauthorized  # Read-only permissions
      return :read_only
    when Net::HTTPClientError   # User has not authorized app
      return :not_authorized
    else
      puts response.body
    end
    return :unknown
  end

  def post_signed_request(endpoint, payload, uuid = @uuid)
    payload.update({
      'api_key' => @uuid,
      'game_id' => @app_id,
      'request_date' => Time.now.to_i,
      'request_id' => Digest::SHA1.hexdigest(Time.now.to_s)[8..16]
    })
    string_to_sign = "POST\n#{@hostname}\n#{endpoint}\n"
    sig_keys = payload.keys.sort
    string_to_sign += sig_keys.map { |k| "#{k}=#{payload[k]}" }.join('&')
    signature = Base64.encode64(OpenSSL::HMAC.digest(OpenSSL::Digest::Digest.new("sha256"), @app_secret, string_to_sign)).strip
    payload.update({'sig' => signature})

    http = Net::HTTP.new @hostname, 443
    http.use_ssl = true

    request = Net::HTTP::Post.new endpoint
    request.set_form_data(payload)
    response = http.request(request)
    case response
    when Net::HTTPSuccess       # User created
      return :authorized
    when Net::HTTPUnauthorized  # Read-only permissions
      return :read_only
    when Net::HTTPClientError   # User has not authorized app
      return :not_authorized
    else
      puts response.body
    end
    return :unknown
  end

  def post_achievement(achievement_id, uuid = @uuid)
    return post_signed_request("/me/achievements.json", {'achievement_id' => achievement_id})
  end

  def post_highscore(score, leaderboard_id = "", uuid = @uuid)
    return post_signed_request("/me/scores.json", {'value' => score, 'leaderboard_id' => leaderboard_id})
  end

  def post_action(action_id, object_instance_id, action_properties = {}, object_properties = {})
    payload = {
       'action_id' => action_id,
       'action_properties' => JSON.generate(action_properties || {}),
       'object_properties' => JSON.generate(object_properties || {})
    }
    payload.update({'object_instance_id' => object_instance_id}) if object_instance_id
    return post_signed_request("/me/actions.json", payload)
  end
end
