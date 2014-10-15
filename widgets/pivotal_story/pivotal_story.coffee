class Dashing.PivotalStory extends Dashing.NestedWidget
  onData: (data) =>
    setTimeout(
      => @setProgress()
      10
    )

  ready: ->
    @setProgress()

  setProgress: ->
    return unless @progress
    percent = @progress.progress
    percent = 0 unless @progress.progress

    $story = $(@node)
    $pie = $story.find('.progress')
    $pie.attr('data-percent', percent)
    $left = $pie.find(".left span")
    $right = $pie.find(".right span")

    if (percent<=50)
      # Hide left
      $left.hide()

      # Adjust right
      deg = 180 - (percent/100*360)
      $right.css(
        "-webkit-transform": "rotateZ(-"+deg+"deg)"
      )
    else
      # Adjust left
      deg = 180 - ((percent-50)/100*360)
      $left.css(
        "-webkit-transform": "rotateZ(-"+deg+"deg)"
      )


