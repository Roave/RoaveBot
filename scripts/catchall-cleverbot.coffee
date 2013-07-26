# Description
#   Send all uncaught commands to cleverbot.
#   Based on:
#   https://github.com/github/hubot-scripts/blob/master/src/scripts/cleverbot.coffee
#
# Dependencies:
#   "cleverbot-node": "0.1.1"
#
# Commands:
#   hubot (.*) - If not caught by another script, replies with cleverbot response.
#
# Author:
#   EvanDotPro

cleverbot = require('cleverbot-node')

module.exports = (robot) ->
  bot_sessions = {}

  robot.catchAll (msg) ->
    search = new RegExp("^@?" + msg.robot.name + "(.+)", "i")
    if msg.message.text and msg.message.text.match(search)
        sessionKey = if msg.message.room then msg.message.room else msg.message.user.name
        if not bot_sessions[sessionKey]?
            bot_sessions[sessionKey] = new cleverbot()
        c = bot_sessions[sessionKey]
        replace = new RegExp("^(@?" + msg.robot.name + "[:,]?)", "i")
        data = msg.message.text.trim().replace(replace, '').trim()
        console.log('« CLEVERBOT ('+sessionKey+'): ' + data)
        c.write(data, (c) =>
            response = c.message.replace /cleverbot/i, msg.robot.name
            console.log('» CLEVERBOT ('+sessionKey+'): ' + response)
            msg.send(response)
        )
