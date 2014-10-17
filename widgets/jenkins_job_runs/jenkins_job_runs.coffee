class Dashing.JenkinsJobRuns extends Dashing.Widget

  ready: ->
    @updateNode()

  onData: (data) ->
    @updateNode()

  updateNode: ->
    $(@node).toggleClass('success', @state is 'success')
