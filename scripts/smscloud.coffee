# Description:
#   Display SMSCloud status information
#
# Commands:
#   hubot smscloud queue - Display SMSCloud message queue size
#   hubot keep us updated on smscloud [every <n> minutes] - Display SMSCloud message queue size every <n> minutes, defaulting to 30
#   hubot send an sms to <number> [with message <message>] - Sends an SMS to a given number, with a given message (or "test")

jayson = require('jayson')

fromNumber = process.env.HUBOT_SMSCLOUD_FROMNUMBER
apiKey = process.env.HUBOT_SMSCLOUD_API_KEY

smscloudClient = jayson.client.http({
    hostname: 'api.smscloud.com',
    path: '/jsonrpc?key=' + apiKey
})

module.exports = (robot) ->
  robot.respond /smscloud queue/i, (msg) ->
    smscloudQueue msg
  
  robot.respond /keep us updated on smscloud(?: every (\d+) minute(?:s)?)?/i, (msg) ->
    minuteInterval = 30
    if msg.match[1]
      minuteInterval = parseInt(msg.match[1])
    smscloudUpdateIntervalId = setInterval () ->
      smscloudQueue msg
    , 1000 * 60 * minuteInterval
    msg.send "Alright, I'll keep you updated"
  
  robot.respond /send an sms to ([\+\d]+)(?: with message (.*))?/i, (msg) ->
    number = msg.match[1].trim()
    message = "test"
    if msg.match[2] != undefined
      message = msg.match[2].trim()
    
    smscloudMessage msg, number, message, (result) ->
      if result.success
        msg.send "Message sent (#{result.smsid})"
      else
        console.log result.error

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

smscloudMessage = (msg, toNumber, message, cb) ->
  smscloudClient.request 'sms.send', [fromNumber, toNumber, message, 1], (err, response) ->
    result = {
      success: true,
      error: null,
      smsid: null
    }
    if err
      result.success = false
      result.error = err
    else
      result.smsid = response.result.sms_id
    
    cb result