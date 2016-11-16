require 'sinatra'
require 'json'
require 'tracker_api'

# Check all ENV variables are set
[
  'PIVOTAL_TRACKER_API_TOKEN',
  'SECRET_TOKEN',
  'GITHUB_OAUTH_TOKEN'
].each do |env|
  unless ENV[env]
    puts "export #{env}="
    exit 1
  end
end


# Endpoints :

get '/' do
  "Give me your pull requests!"
end

# /github... who knows, if in future we support more sources?
post '/github' do
  payload_body = request.body.read
  verify_signature(payload_body)

  process_github_event(JSON.parse(payload_body))
end


# Logic :

# assume PT IDs are always at least 9 digits long
TRACKER_ID_REGEXP = /([0-9]{9,})/

# GitHub payload signature verification
def verify_signature(payload_body)
  signature = 'sha1=' + OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha1'), ENV['SECRET_TOKEN'], payload_body)
  return halt 401, "Signatures didn't match!" unless Rack::Utils.secure_compare(signature, request.env['HTTP_X_HUB_SIGNATURE'])
end

def process_github_event(payload_json)
  # We are interested only in new pull requests
  return unless payload_json['action'] == 'opened' && payload_json.key?('pull_request')

  puts 'It\'s a Opened Pull Request!'
  head_branch = payload_json['pull_request']['head']['ref']
  puts "Branch: #{head_branch}"

  tracker_id = tracker_id_from_branch(head_branch)
  return unless tracker_id

  handle_story_pull_request(tracker_id, pull_request)
end

def handle_story_pull_request(tracker_id, pull_request)
  story = get_pt_story(tracker_id)
  return unless story

  # finish story
  finish_story(story)
  # add PR url to story comments
  add_comment_to_story(
    story,
    "Opened new PR: #{payload_json['pull_request']['html_url']}"
  )
  # add Story URL to PR
  add_story_url_to_pr_description(payload_json, story)
end

def tracker_id_from_branch(head_branch)
  # Retrieve Tracker ID from original branch name
  tracker_id_matches = TRACKER_ID_REGEXP.match head_branch
  return unless tracker_id_matches

  puts "It has tracker ID"
  tracker_id = tracker_id_matches[1]
  puts "Tracker ID: ##{tracker_id}"

  tracker_id
end

def finish_story(story)
  return unless story
  # Mark tracker issue as "finished"
  story.current_state = 'finished'
  story.save
end

def add_comment_to_story(story, comment)
  return unless story
  url = "https://www.pivotaltracker.com/services/v5/projects/#{story.project_id}/stories/#{story.id}/comments"

  Excon.post(url,
    body: { text: comment }.to_json,
    headers: {
      "Content-Type" => "application/json",
      "X-TrackerToken" => ENV['PIVOTAL_TRACKER_API_TOKEN']
    }
  )
end

def get_pt_story(tracker_id)
  @tracker ||= TrackerApi::Client.new(token: ENV['PIVOTAL_TRACKER_API_TOKEN'])
  story = @tracker.story(tracker_id)

  unless story
    puts "Tracker ID #{tracker_id} doesnt exist in Pivotal"
    return
  else
    story
  end
end

def add_story_url_to_pr_description(pull_request, story)
  return unless story

  old_body = pull_request['pull_request']['body']
  new_body = "PT: #{story.url}\r\n\r\n#{old_body}"
  url = pull_request['pull_request']['url']

  Excon.patch(url,
    body: { body: new_body }.to_json,
    headers: {
      "Content-Type" => "application/json",
      "Authorization" => "token #{ENV['GITHUB_OAUTH_TOKEN']}"
    }
  )
end
