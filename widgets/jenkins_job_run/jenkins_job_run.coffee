class Dashing.JenkinsJobRun extends Dashing.NestedWidget

  @accessor 'title', ->
    @name || @id[12...]

  @accessor 'icon', ->
    switch @state
      when 'success' then 'ok'
      when 'failed' then 'remove'
      else 'question'


