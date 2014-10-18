class Dashing.IssueCount extends Dashing.Widget
  ready: ->
    @updateNode()

  onData: (data) ->
    @updateNode()

  updateNode: ->
    #$(@get('node')).toggleClass('status-alert', @get('high') > 0)

