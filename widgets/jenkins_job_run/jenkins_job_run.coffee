class Dashing.JenkinsJobRun extends Dashing.NestedWidget

  @accessor 'title', ->
    @get('name') || @get('id')[12...]

  @accessor 'icon', ->
    switch @get('state')
      when 'success' then 'ok'
      when 'failed' then 'remove'
      else 'question'
