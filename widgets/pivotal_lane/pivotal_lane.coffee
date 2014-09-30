class Dashing.PivotalLane extends Dashing.Widget

  onData: (data) =>
    setTimeout(
      => @setProgress()
      10
    )

  setProgress: ->
    return unless @stories
    $stories = $(@node).find('li')
    return unless $stories.length > 0
    for story, index in @stories
      percent = story.progress
      percent = 0 if story.progress is '??'

      $story = $($stories[index])
      console.log index, $story[0]

      $pie = $story.find('.progress')
      $pie.attr('data-percent', story.progress)
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

