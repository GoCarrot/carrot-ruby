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

  # Create a new Carrot instance.
  #
  # @param app_id [String]     Facebook Application Id for your application.
  # @param app_secret [String] Carrot Application Secret for your application.
  # @param uuid [String]       a per-user unique identifier. We suggest using email address or the Facebook 'third_party_id'. You may also specify `nil` and instead provide a value as you call methods.
  # @param hostname [String]   the hostname to use for Carrot API endpoints.
  def initialize(app_id, app_secret, uuid = nil, hostname = 'gocarrot.com')
    @app_id = app_id
    @app_secret = app_secret
    @uuid = uuid
    @hostname = hostname
  end

  # Validate a user with the Carrot service.
  #
  # @param access_token [String] the Facebook user access token for the user.
  # @param uuid [String]         a per-user unique identifier or `nil` to use the value of {Carrot#uuid}. We suggest using email address or the Facebook 'third_party_id'.
  #
  # @return [Symbol] one of: `:authorized`, `:read_only`, `:not_authorized` or `:unknown`
  def create_user(access_token, uuid = @uuid)
    http = Net::HTTP.new @hostname, 443
    http.use_ssl = true

    request = Net::HTTP::Post.new "/games/#{@app_id}/users.json"
    request.set_form_data({'access_token' => access_token, 'api_key' => @uuid})
    response = http.request(request)
    case response
    when Net::HTTPSuccess           # User created
      return :authorized
    when Net::HTTPUnauthorized      # Read-only permissions
      return :read_only
    when Net::HTTPMethodNotAllowed  # User has not authorized app
      return :not_authorized
    else
      puts response.body
    end
    return :unknown
  end

  # Post an achievement to the Carrot service.
  #
  # @param achievement_id [String] the achievement identifier.
  # @param uuid [String, nil]      a per-user unique identifier or `nil` to use the value of {Carrot#uuid}. We suggest using email address or the Facebook 'third_party_id'.
  #
  # @return [Symbol] one of: `:success`, `:read_only`, `:not_found`, `:not_authorized` or `:unknown`
  def post_achievement(achievement_id, uuid = @uuid)
    return post_signed_request("/me/achievements.json", {'api_key' => uuid, 'achievement_id' => achievement_id})
  end

  # Post a high score to the Carrot service.
  #
  # @param score [String, Integer] the high score value to post.
  # @param leaderboard_id [String] the leaderboard identifier to which the score should be posted.
  # @param uuid [String]           a per-user unique identifier or `nil` to use the value of {Carrot#uuid}. We suggest using email address or the Facebook 'third_party_id'.
  #
  # @return [Symbol] one of: `:success`, `:read_only`, `:not_found`, `:not_authorized` or `:unknown`
  def post_highscore(score, leaderboard_id = "", uuid = @uuid)
    return post_signed_request("/me/scores.json", {'api_key' => uuid, 'value' => score, 'leaderboard_id' => leaderboard_id})
  end

  # Post an Open Graph action to the Carrot service.
  #
  # If creating an object, you are required to include 'title', 'description', 'image_url' and
  # 'object_type' in `object_properties`.
  #
  # @param action_id [String]          Carrot action id.
  # @param object_instance_id [String] the object instance id of the Carrot object type to create or post; use `nil` if you are creating a throw-away object.
  # @param action_properties [Hash]    the properties to be sent along with the Carrot action, or `nil`.
  # @param object_properties [Hash]    the properties for the new object, if creating an object, or `nil`.
  # @param uuid [String] a per-user unique identifier or `nil` to use the value of {Carrot#uuid}. We suggest using email address or the Facebook 'third_party_id'.
  #
  # @return [Symbol] one of: `:success`, `:read_only`, `:not_found`, `:not_authorized` or `:unknown`
  def post_action(action_id, object_instance_id, action_properties = {}, object_properties = {}, uuid = @uuid)
    payload = {
      'api_key' => uuid,
      'action_id' => action_id,
      'action_properties' => JSON.generate(action_properties || {}),
      'object_properties' => JSON.generate(object_properties || {})
    }
    payload.update({'object_instance_id' => object_instance_id}) if object_instance_id
    return post_signed_request("/me/actions.json", payload)
  end

  # Post a 'Like' to the Carrot service.
  #
  # @param object_type [Symbol] one of: `:game`, `:publisher`, `:achievement`, or `:object`.
  # @param object_id [String]   if `:achievement` or `:object` is specified as `object_type` this is the identifier of the achievement or object.
  # @param uuid [String] a per-user unique identifier or `nil` to use the value of {Carrot#uuid}. We suggest using email address or the Facebook 'third_party_id'.
  #
  # @return [Symbol] one of: `:success`, `:read_only`, `:not_found`, `:not_authorized` or `:unknown`
  def post_like(object_type, object_id = nil, uuid = @uuid)
    payload = {
      'api_key' => uuid,
      'object' => "#{object_type}#{":#{object_id}" if object_id}"
    }
    return post_signed_request("/me/like.json", payload)
  end

  private

  def post_signed_request(endpoint, payload, uuid = @uuid)
    payload.update({
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
    when Net::HTTPSuccess           # Success
      return :success
    when Net::HTTPUnauthorized      # User has read-only permissions
      return :read_only
    when Net::HTTPNotFound          # Resource not found
      return :not_found
    when Net::HTTPMethodNotAllowed  # User has not authorized app
      return :not_authorized
    else
      puts response.body
    end
    return :unknown
  end
end
