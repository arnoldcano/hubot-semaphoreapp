# Description
#   Uses Semaphore's API to start rollbacks.
#
# Dependencies:
#   None
#
# Configuration:
#   HUBOT_SEMAPHOREAPP_AUTH_TOKEN
#     Your authentication token for Semaphore API
#
#   HUBOT_SEMAPHOREAPP_DEPLOY
#     If this variable is set and is non-zero, this script will register the `hubot deploy` commands.
#
#   HUBOT_SEMAPHOREAPP_DEFAULT_SERVER
#     Your default semaphore server or `prod`.
#
#   HUBOT_SEMAPHOREAPP_DEFAULT_BRANCH
#     Your default semaphore branch or `master`.
#
#   HUBOT_SEMAPHOREAPP_DEFAULT_ROLE
#     Your default semaphore role or `deploy`.
#
# Commands
#   hubot rollback project/branch by n_builds to server - rolls back project/branch by n_builds to server
#   hubot rollback project/branch to server - rolls back project/branch by 1 to server
#   hubot rollback project by n_builds to server - rolls back project/master by n_builds to server
#   hubot rollback project to server - rolls back project/master by 1 to server
#   hubot rollback project/branch by n_builds - rolls back project/branch by n_builds to 'prod'
#   hubot rollback project/branch - rolls back project/branch by 1 to 'prod'
#   hubot rollback project by n_builds - rolls back project/master by n_builds to 'prod'
#   hubot rollback project - rolls back project/master by 1 to 'prod'
#
# Author:
#   arnoldcano

SemaphoreApp = require './lib/app'

module.exports = (robot) ->
  default_branch = process.env.HUBOT_SEMAPHOREAPP_DEFAULT_BRANCH || 'master'
  default_server = process.env.HUBOT_SEMAPHOREAPP_DEFAULT_SERVER || 'prod'
  default_role = process.env.HUBOT_SEMAPHOREAPP_DEFAULT_ROLE || 'deploy'
  default_n_builds = 1

  unless process.env.HUBOT_SEMAPHOREAPP_DEPLOY?
    console.log 'Semaphore deploy commands disabled; export HUBOT_SEMAPHOREAPP_DEPLOY to turn them on'
    return

  robot.respond /rollback (.*)/, (msg) =>
    unless process.env.HUBOT_SEMAPHOREAPP_AUTH_TOKEN?
      return msg.reply "I need HUBOT_SEMAPHOREAPP_AUTH_TOKEN for this to work."
    unless robot.auth.hasRole(msg.envelope.user, default_role)
      return msg.reply "Can't find role #{default_role} for user"

    command = msg.match[1]
    aSlashBByCToD = command.match /(.*?)\/(.*)\s+by\s+(\d)\s+to\s+(.*)/ # project/branch by n_builds to server
    aSlashBToC = command.match /(.*?)\/(.*)\s+to\s+(.*)/                # project/branch to server
    aByBToC = command.match /(.*)\s+by\s+(\d)\s+to\s+(.*)/              # project by n_builds to server
    aToB = command.match /(.*)\s+to\s+(.*)/                             # project to server
    aSlashBByC = command.match /(.*?)\/(.*)\s+by\s+(\d)/                # project/branch by n_builds
    aSlashB = command.match /(.*?)\/(.*)/                               # project/branch

    [project, branch, n_builds, server] = switch
      when aSlashBByCToD? then aSlashBByCToD[1..4]
      when aSlashBToC? then [aSlashBToC[1], aSlashBToC[2], default_n_builds, aSlashBToC[3]]
      when aByBToC? then [aByBToC[1], default_branch, aByBToC[2], aByBToC[3]]
      when aToB? then [aToB[1], default_branch, default_n_builds, aToB[2]]
      when aSlashBByC? then [aSlashBByC[1], aSlashBByC[2], aSlashBByC[3], default_server]
      when aSlashB? then [aSlashB[1], aSlashB[2], default_n_builds, default_server]
      else [command, default_branch, default_n_builds, default_server]

    robot.logger.debug "SEMAPHOREAPP rollback #{project}/#{branch} by #{n_builds} to #{server}"

    module.exports.rollback msg, project, branch, n_builds, server

module.exports.rollback = (msg, project, branch, n_builds, server) ->
  app = new SemaphoreApp(msg)
  app.getProjects (allProjects) ->
    [project_obj] = (p for p in allProjects when p.name == project)
    unless project_obj
      return msg.reply "Can't find project #{project}"
    [branch_obj] = (b for b in project_obj.branches when b.branch_name == branch)
    unless branch_obj
      return msg.reply "Can't find branch #{project}/#{branch}"
    [server_obj] = (s for s in project_obj.servers when s.server_name == server)
    unless server_obj
      return msg.reply "Can't find server #{server} for project #{project}"

    app.getBranches project_obj.hash_id, (allBranches) ->
      app.getServers project_obj.hash_id, (allServers) ->
        [branch_id] = (b.id for b in allBranches when b.name == branch)
        [server_id] = (s.id for s in allServers when s.name == server)
        app.createDeploy project_obj.hash_id, branch_id, (branch_obj.build_number - n_builds), server_id, (json) ->
          msg.send "Rolling back #{project}/#{branch} by #{n_builds} to #{server} \n  #{json.html_url}"
