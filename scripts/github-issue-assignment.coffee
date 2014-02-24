# Description:
#   Assign Github issues by username from within chat.
#
# Dependencies:
#   githubot
#
# Configuration:
#   HUBOT_GITHUB_TOKEN
#   HUBOT_GITHUB_USER - default repo user to assume (optional)
#   HUBOT_GITHUB_REPO - default repo name to assume (optional)
#   HUBOT_GITHUB_ISSUE_ASSIGN_TEAMID - team id (with pull access) to add assignee to
#
# Commands:
#   hubot assign <assignee> [[<repo user>]/<repo name>]<#issue>
#
# Notes:
#   - You can create a personal access token here: https://github.com/settings/applications
#   - Token will need to the following permissions:
#     - `admin:org` (`write:org` once this bug is fixed: https://github.com/isaacs/github/issues/154)
#     - `public_repo`

module.exports = (robot) ->

  unless process.env.HUBOT_GITHUB_USER? and process.env.HUBOT_GITHUB_REPO?
    robot.logger.warning 'You likely want to set both HUBOT_GITHUB_USER and HUBOT_GITHUB_REPO to sensible defaults [hubot-auth]'

  github = require('githubot')(robot)

  github.handleErrors (response) ->
    console.log response

  REGEX = ///        # match [#]
    assign
    \ +
    ([\w._-]+)       # assignee [1]
    \ +
    (                # qualified repo [2]
      (
        ([\w._-]+)\/ # repo user [4]
      )?
      ([\w._-]+)     # repo name [5]
    )?
    ((gh|\#)(\d+))   # issue number [8]
  ///i

  team_id = process.env.HUBOT_GITHUB_ISSUE_ASSIGN_TEAMID

  robot.respond REGEX, (msg) ->

    assignee = msg.match[1]
    issue_id = msg.match[8]
    qualified_repo = github.qualified_repo msg.match[2]

    unless qualified_repo?
      msg.send "Not enough information provided to determine desired repo."
      return

    github.get "teams/#{team_id}/members", (team_members) ->
      on_team = false
      for user in team_members
        on_team = true if user.login == assignee

      unless on_team
        github.put "teams/#{team_id}/members/#{assignee}", {}, (team) ->
          return

      github.patch "repos/#{qualified_repo}/issues/#{issue_id}", {assignee: assignee}, (issue) ->
        msg.send "Issue #{qualified_repo}##{issue_id} assigned to #{assignee}!"
        msg.send issue.html_url
