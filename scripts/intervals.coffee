# Description:
#   Manage recurring messages
#
# Commands:
#   shut up - clear all recurring messages

module.exports = (robot) ->
  class IntervalManager
    intervals: [],
    add: (cb, interval) ->
      id = setInterval(cb, interval)
      robot.intervals.intervals.push(id)
      return id
    remove: (id) ->
      index = robot.intervals.intervals.indexOf(id)
      clearInterval(robot.intervals.intervals[index])
      robot.intervals.intervals.splice(index, 1)
    clear: () ->
      clearInterval(interval) for interval in robot.intervals.intervals
      robot.intervals.intervals = []
  
  robot.intervals = new IntervalManager
  
  robot.respond /shut up/i, (msg) ->
    robot.intervals.clear()
    msg.emote "shuts its noisy trap"
