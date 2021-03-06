# Description:
#   Display SMSCloud status information
#
# Commands:
#   hubot smscloud queue - Display SMSCloud message queue size
#   hubot smscloud culprit - Display the largest DID queue
#   hubot keep us updated on smscloud [every <n> minutes] - Display SMSCloud message queue size every <n> minutes, defaulting to 30
#   hubot send an sms to <toNumber> [from <fromNumber>] [with message <message>] - Sends an SMS to a given number, from a given number, with a given message (or "test")
#   hubot what carrier for <number> - NVS lookup for a given number
#   hubot whose number is <number> - SMSCloud account lookup for number
#   hubot tell me about number <number> - SMSCloud number information lookup
#   hubot are we having queue (?:problems|issues) [greater than <n>]? - Check the differential on database queues to redis queues

jayson = require('jayson')

mainFromNumber = process.env.HUBOT_SMSCLOUD_FROMNUMBER
apiKey = process.env.HUBOT_SMSCLOUD_API_KEY

smscloudClient = jayson.client.http({
    hostname: 'api.smscloud.com',
    path: '/jsonrpc?key=' + apiKey
})

module.exports = (robot) ->
  smscloudUpdateIntervalId = null

  robot.respond /smscloud queue/i, (msg) ->
    hasAccess = robot.auth.hasRole msg.message.user, 'smscloud'
    if hasAccess isnt true
      return false
    smscloudQueue msg
  
  robot.respond /smscloud culprit/i, (msg) ->
    hasAccess = robot.auth.hasRole msg.message.user, 'smscloud'
    if hasAccess isnt true
      return false
    smscloudLargestQueue msg
  
  robot.respond /keep us updated on smscloud(?: every (\d+) minute(?:s)?)?/i, (msg) ->
    hasAccess = robot.auth.hasRole msg.message.user, 'smscloud'
    if hasAccess isnt true
      return false
    if smscloudUpdateIntervalId
      robot.intervals.remove smscloudUpdateIntervalId
      smscloudUpdateIntervalId = null
  
    minuteInterval = 30
    if msg.match[1]
      minuteInterval = parseInt(msg.match[1])
    intervalClosure = do (msg) ->
      origMsg = new robot.Response(msg.robot, msg.message, msg.match)
      return ->
        smscloudQueue origMsg
    smscloudUpdateIntervalId = robot.intervals.add intervalClosure, 1000 * 60 * minuteInterval
    msg.send "Alright, I'll keep you updated"
  
  robot.respond /send (?:an )?sms to ([\+\d]+)(?: from ([\+\d]+))?(?: with message (.*))?/i, (msg) ->
    hasAccess = robot.auth.hasRole msg.message.user, 'smscloud'
    if hasAccess isnt true
      return false
    toNumber = msg.match[1].trim()
    if msg.match[2] != undefined
      fromNumber = msg.match[2].trim()
    else
      fromNumber = mainFromNumber
    message = "test"
    if msg.match[3] != undefined
      message = msg.match[3].trim()
    
    smscloudMessage msg, toNumber, fromNumber, message, (result) ->
      msg.send "Message sent (#{result.sms_id})"

  robot.respond /(?:what|which) carrier for ([\+\d]+)/i, (msg) ->
    hasAccess = robot.auth.hasRole msg.message.user, 'smscloud'
    if hasAccess isnt true
      return false
    number = msg.match[1]
    smscloudCarrierLookup msg, number, (info) ->
      msg.send "That number is from a #{info.carrier_type} carrier, #{info.carrier_name} in #{info.location}"
  
  robot.respond /whose number is ([\+\d]+)/i, (msg) ->
    hasAccess = robot.auth.hasRole msg.message.user, 'smscloud'
    if hasAccess isnt true
      return false
    number = msg.match[1]
    smscloudNumberLookup msg, number, (info) ->
      msg.send "That number is from account #{info.account_name} (#{info.account_id})"
  
  robot.respond /tell me about number ([\+\d]+)/i, (msg) ->
    hasAccess = robot.auth.hasRole msg.message.user, 'smscloud'
    if hasAccess isnt true
      return false
    number = msg.match[1]
    smscloudNumberLookup msg, number, (info) ->
      response = "#{number}: number id #{info.id}, provider is #{info.provider}, internal note is '#{info.internal_note}', rate limit of #{info.rate_limit}ms, account #{info.account_name} (#{info.account_id}), api key id is #{info.api_key_id}"
      if info.rewrite_number_id
        response = "#{response}, rewriting to number id #{info.rewrite_number_id}"
      if info.incoming_rewrite_number_id
        response = "#{response}, incoming rewriting to number id #{info.incoming_rewrite_number_id}"
      msg.send response
  
  robot.respond /are we having queue problems(?: greater than (\d+))?\??/i, (msg) ->
    hasAccess = robot.auth.hasRole msg.message.user, 'smscloud'
    if hasAccess isnt true
      return false
    differential = 5
    if msg.match[1] != undefined
      differential = parseInt(msg.match[1].trim())
    smscloudFaultyQueues msg, differential, (result) ->
      if result.length > 0
        numberMessages = ("#{queue.did} has #{queue.length} messages and #{queue.real_length} queued" for queue in result)
        msg.send numberMessages.join(", ")
      else
        msg.send "Not that I can tell" 

smscloudQueue = (msg) ->
  msg.http('http://smscloud.com/status/queue-size')
    .get() (err, resp, body) ->
      status = JSON.parse(body)
      if status.status == "okay"
        msg.send "SMSCloud is doing fine with #{status.length} messages queued"
      else if status.status == "warning"
        msg.send "SMSCloud is busy with #{status.length} messages queued"
      else if status.status == "alert"
        msg.send "SMSCloud is having a hard time with #{status.length} messages queued"
        smscloudLargestQueue msg
        smscloudFaultyQueues msg, 5, (result) ->
          if result.length > 0
            msg.send "#{result.length} queues might be faulty"

smscloudLargestQueue = (msg) ->
  msg.http('http://smscloud.com/status/largest-queue')
    .get() (err, resp, body) ->
      queue = JSON.parse(body)
      msg.send "The largest DID queue is #{queue.length} message(s), for #{queue.number}"

smscloudMessage = (msg, toNumber, fromNumber, message, cb) ->
  smscloudClient.request 'sms.send', [fromNumber, toNumber, message, 1], (err, response) ->
    if err || response.result == null
      msg.send "Sorry, I couldn't send that message"
    else
      cb response.result

smscloudCarrierLookup = (msg, number, cb) ->
  smscloudClient.request 'nvs.carrierLookup', [number], (err, response) ->
    if err || response.result == null
      msg.send "Sorry, I couldn't look that number up"
    else
      cb response.result

smscloudNumberLookup = (msg, number, cb) ->
  smscloudClient.request 'admin.numberInfo', [number], (err, response) ->
    if err || response.result == null
      msg.send "Sorry, I couldn't look that number up"
    else
      cb response.result

smscloudRealQueueSizes = (msg, cb) ->
  smscloudClient.request 'admin.realQueueSizes', [], (err, response) ->
    if err || response.result == null
      msg.send "Sorry, I couldn't fetch the real queue sizes"
    else
      cb response.result

smscloudFaultyQueues = (msg, differential, cb) ->
  smscloudRealQueueSizes msg, (result) ->
    result = (queue for queue in result when Math.abs(queue.length - queue.real_length) >= differential)
    cb result
