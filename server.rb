require 'sinatra'
require 'json'
require 'tracker_api'

unless ENV['PIVOTAL_TRACKER_API_TOKEN']
  puts "export PIVOTAL_TRACKER_API_TOKEN="
  exit 1
end

unless ENV['SECRET_TOKEN']
  puts "export SECRET_TOKEN="
  exit 1
end


# Endpoints :

# /github... who knows, if in future we support more sources?
post '/github' do
  payload_body = request.body.read
  verify_signature(payload_body)

  process_github_event(JSON.parse(payload_body))
end


# Logic :

# assume PT IDs are always at least 9 digits long
TRACKER_ID_REGEXP = /([0-9]{9,})-/

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

  finish_story_from_branch(head_branch)
end

def finish_story_from_branch(head_branch)
  tracker_id = tracker_id_from_branch(head_branch)
  return unless tracker_id
  finish_story(tracker_id)
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

def finish_story(tracker_id)
  # Mark tracker issue as "finished"
  tracker = TrackerApi::Client.new(token: ENV['PIVOTAL_TRACKER_API_TOKEN'])
  story = tracker.story(tracker_id)
  story.state = 'finished'
  story.save
end
