class Dashing.JenkinsJobMessages extends Dashing.NestedWidget
  ready: ->
    setInterval(@startTime, 500)

  @accessor 'lastMessages', ->
    (@get('messages') || [])[-2..-1]

  startTime: =>
    today = new Date()

    h = today.getHours()
    m = today.getMinutes()
    h = @formatTime(h)
    m = @formatTime(m)
    @set('time', "#{h}:#{m}")

  formatTime: (i) ->
    if i < 10 then "0" + i else i
