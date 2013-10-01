# Description:
#   Display SMSCloud status information
#
# Commands:
#   hubot smscloud queue - Display SMSCloud message queue size
#   hubot keep us updated on smscloud [every <n> minutes] - Display SMSCloud message queue size every <n> minutes, defaulting to 30

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
