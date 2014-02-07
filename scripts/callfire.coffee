# Description:
#   Display SMSCloud status information
#
# Commands:
#   hubot callfire set credentials <username> <password> - Set your CallFire API credentials
#   hubot callfire what credentials - Display hints about what your current API credentials are
#   hubot callfire inspect <client> <method> - Inspect a client method
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
  
  robot.respond /callfire api (\w+) (\w+)(?: (.*))?/i, (msg) ->
    clientType = msg.match[1].trim()
    clientMethod = msg.match[2].trim()
    if msg.match[3] != undefined
      parameters = msg.match[3].trim()
    else
      parameters = ''
    
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
    if client == undefined
      msg.send "That service is not recognized"
      return
    
    method = client[clientMethod]
    if method == undefined
      msg.send "That service method is not recognized"
      return
    
    callback = callfireHandleResponse(msg, client)
    
    if id == undefined
      id = request
      request = {}
    
    if method.length == 1
      method.call(client, callback)
    else if method.length == 2
      method.call(client, id, callback)
    else if method.length == 3
      method.call(client, id, request, callback)
  
  robot.respond /callfire inspect (\w+) (\w+)/i, (msg) ->
    clientType = msg.match[1].trim()
    clientMethod = msg.match[2].trim()
  
    msg.send callfire.client[clientType].prototype[clientMethod]

callfireHandleResponse = (msg, client) ->
  callback = (response) ->
    response = client.response(response)
    switch response.type
      when 'Resource' then msg.send JSON.stringify(response.resource, undefined, ' ')
      when 'ResourceList' then msg.send "Total Results: #{response.totalResults}\n" + JSON.stringify(response.resources, undefined, ' ')
      when 'ResourceException' then msg.send "[#{response.httpStatus}] #{response.message}"
      when 'ResourceReference' then msg.send "Not implemented"
    return
  
  return callback
