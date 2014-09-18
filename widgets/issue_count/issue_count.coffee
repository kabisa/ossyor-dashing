class Dashing.IssueCount extends Dashing.Widget
  onData: (data) ->
    if data.high > 0
      # add new class
      $(@get('node')).addClass "status-alert"
    else
      $(@get('node')).removeClass "status-alert"

