# Finish Pivotal Tracker story with created Pull Request

Pull Request flow in Pivotal Tracker automation:

1. Start your Pivotal Tracker story and copy ID: `123456789`
2. Create your story branch including ID: `feature/123456789-amazing-feature`
3. Do your work
4. Create PR in GitHub on the branch -> *Story in PT is now finished*

## Configure

1. Get your Pivotal Tracker API token in your Profile page
2. Create new GitHub personal token (Profile settings / Personal access tokens), allow all Pull Request scope
2. Setup this app to run somewhere with tokens in ENV as below
3. Create new webhooks in your GitHub repositories with secret set in `SECRET_TOKEN`. Select only "Pull Request" events.
4. Enjoy :)

## Starting

```
export PIVOTAL_TRACKER_API_TOKEN=your_pivotal_tracker_API_token
export GITHUB_OAUTH_TOKEN=your_github_token
export SECRET_TOKEN=$( ruby -rsecurerandom -e 'puts SecureRandom.hex(20)' )
ruby server.rb
```

whooo
