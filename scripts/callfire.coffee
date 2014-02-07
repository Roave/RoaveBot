# Description:
#   Display SMSCloud status information
#
# Commands:
#   hubot callfire set credentials <username> <password> - Set your CallFire API credentials
#   hubot callfire what credentials - Display hints about what your current API credentials are
#   hubot callfire api <client> <method> [<parameter> ...] - Call a method on an API client

callfire = require('callfire')
util = require('util')

module.exports = (robot) ->
  robot.respond /callfire set credentials (\w+) (\w+)/i, (msg) ->
    user = robot.brain.userForId(msg.message.user.id)
    user.callfire = {
      username: msg.match[1].trim(),
      password: msg.match[2].trim()
    }
    msg.send "Your CallFire API credentials have been set"
  
  robot.respond /callfire what credentials/i, (msg) ->
    user = robot.brain.userForId(msg.message.user.id)
    username = user.callfire.username
    password = user.callfire.password
    if username == undefined or password == undefined
      msg.send "You don't have any credentials"
    else
      maskedUsername = username.substring(0, 5) + "******"
      maskedPassword = password.substring(0, 5) + "******"
      msg.send "Your credentials are: #{maskedUsername}, #{maskedPassword}"
  
  robot.respond /callfire api (\w+) (\w+) (.*)?/i, (msg) ->
    clientType = msg.match[1].trim()
    clientMethod = msg.match[2].trim()
    parameters = msg.match[3].trim()

    user = robot.brain.userForId(msg.message.user.id)
    username = user.callfire.username
    password = user.callfire.password
    if username == undefined or password == undefined
      msg.send "You don't have any credentials"
      return
    
    if parameters.length > 0
      if parameters.substring(0, 1) == "{"
        request = JSON.parse(parameters)
      else
        splitParams = parameters.split(" ", 2)
        id = splitParams[0]
        if splitParams[1] != undefined and splitParams[1].substring(0, 1) == "{"
          request = JSON.parse(splitParams[1])
    
    client = callfire.client(username, password, clientType)
    callback = callfireHandleResponse(msg, client)
    
    if id != undefined
      if request != undefined
        client[clientMethod](id, request, callback)
      else
        client[clientMethod](id, callback)
    else
      if request != undefined
        client[clientMethod](request, callback)

callfireHandleResponse = (msg, client) ->
  callback = (response) ->
    response = client.response(response)
    msg.send util.inspect(response)
  
  return callback
