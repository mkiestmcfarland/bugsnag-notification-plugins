NotificationPlugin = require "../../notification-plugin"

class GitLabIssue extends NotificationPlugin
  @baseUrl: (config) ->
    "#{config.gitlab_url}/api/v3/projects"

  @issuesUrl: (config) ->
    "#{@baseUrl(config)}/#{encodeURIComponent(config.project_id)}/issues"

  @issueUrl: (config, issueId) ->
    @issuesUrl(config) + "/" + issueId

  @notesUrl: (config, issueId) ->
    @issueUrl(config, issueId) + "/notes"

  @gitlabRequest: (req, config) ->
    req.set("User-Agent", "Bugsnag").set("PRIVATE-TOKEN", config.private_token)

  @openIssue: (config, event, callback) ->
    # Build the ticket
    payload =
      title: @title(event)
      description: @markdownBody(event)
      # Regex removes surrounding whitespace around commas while retaining inner whitespace
      # and then creates an array of the strings
      labels: (config?.labels || "bugsnag").trim().split(/\s*,\s*/).compact(true).join(",")

    @gitlabRequest(@request.post(@issuesUrl(config)), config)
      .send(payload)
      .on("error", callback)
      .end (res) ->
        return callback(res.error) if res.error
        callback null,
          id: res.body.id
          url: "#{config.gitlab_url}/#{config.project_id}/issues/#{res.body.id}"

  @ensureIssueOpen: (config, issueId, callback) ->
    @gitlabRequest(@request.put(@issueUrl(config, issueId)), config)
      .send({state_event: "reopen"})
      .on "error", (err) ->
        callback(err)
      .end (res) ->
        callback(res.error)

  @addCommentToIssue: (config, issueId, comment) ->
    @gitlabRequest(@request.post(@notesUrl(config, issueId)), config)
      .send({body: comment})
      .on("error", console.error)
      .end()

  @receiveEvent: (config, event, callback) ->
    if event?.trigger?.type == "reopened"
      if event.error?.createdIssue?.id
        @ensureIssueOpen(config, event.error.createdIssue.id, callback)
        @addCommentToIssue(config, event.error.createdIssue.id, @markdownBody(event))
    else
      console.log config
      @openIssue(config, event, callback)

module.exports = GitLabIssue
