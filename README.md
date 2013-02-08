# @markup markdown
# @title README
# @author Carrot Inc.

Carrot
============
The GoCarrot gem allows you to interact with the service provided by [Carrot](http://gocarrot.com).

# Installing
To install Carrot use the following command:

	gem install gocarrot

(Add `sudo` if you're installing under a POSIX system as root)

Or include it in a `Gemfile`:

	gem 'gocarrot'
	# or
	gem 'gocarrot', github: 'GoCarrot/carrot-ruby'

# Usage
Carrot works by sending [Open Graph](https://developers.facebook.com/docs/concepts/opengraph/) actions from the Carrot service at the request of your application in response to user actions. A user must authorize your application on Facebook and allow the 'publish_actions' permission.

## Creating an Instance
Create a new instance of Carrot and specify your Facebook App Id and Carrot Secret during creation. You can optionally specify a user-id at time of creation, or you may specify the user-id when you make calls to the Carrot instance. It is important that this user-id be unique per-user, failure to ensure this will cause actions to be posted on behalf of the wrong user. We suggest using the email of a user or the 'third_party_id' that Facebook provides.

This is an example of creating a new Carrot instance:

	@graph = Koala::Facebook::API.new(params[:oauth_token])
	@user = @graph.get_object("me", args={:fields => [:third_party_id]})

	carrot = Carrot.new(ENV["FACEBOOK_APP_ID"], ENV["CARROT_SECRET"], @user['third_party_id'])

## Validating Users
Once your Carrot instance has been created, validate the user with carrot by calling {Carrot#validate_user}. This will return one of several values: `:authorized`, `:read_only`, or `:unknown`

* If the return value is `:authorized` then the Carrot service is ready to recieve actions on behalf of this user.
* If the return value is `:read_only` then the user has not authorized the 'publish_actions' permission for your app on Facebook and you should call {Carrot#validate_user} once the user has allowed the 'publish_actions' permission.
* If the return value is `:unknown` then something unexpected has gone wrong and the server cannot determine the status for the user.

	carrot.validate_user(params[:oauth_token])

## Making Requests

All requests posted to the Carrot service will return the status of the request: `:success`, `:read_only`, `:not_found`, `:not_authorized`, or `:unknown`

* If the return value is `:success` the action succeeded.
* If the return value is `:read_only` the user has de-authorized the 'publish_actions' permission for your app.
* If the return value is `:not_found` the achievement, object, or other identifier specified was not found on the server.
* If the return value is `:not_authorized` the user has deauthorized the app.
* If the return value is `:unknown` then something unexpected has gone wrong.

### Achievements
To post an achievement simply use {Carrot#post_achievement} specifying the achievement identifier of the achievement to earn.

	carrot.post_achievement(:chicken)

### High Scores
To post a high score for a user use {Carrot#post_highscore} passing along the value of the score and an optional leaderboard identifier which is reserved for future use.

	carrot.post_highscore(42)

### Open Graph actions
This is an example from one of our test apps, [Fire](https://apps.facebook.com/litonfire) which allows you to use the action 'light' on a profile, resulting in the very amusing Open Graph action: `[User] lit [Profile] on Fire.`

	if carrot.post_action(:light, @friend['third_party_id'], nil, {
			title: @friend['name'],
			object_type: :profile,
			image_url:'https://graph.facebook.com/' + params[:friend_id] + '/picture?type=square&width=200&height=200',
			identifier: @friend['third_party_id'],
			description: "Is on fire!",
			fields: {
				'fb:profile_id' => @friend['third_party_id']
			}
		}) === :success
		return {code: 200}.to_json
	else
		halt 403, {code: 403}.to_json
	end
