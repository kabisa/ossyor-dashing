class Dashing.BackgroundImage extends Dashing.Widget

  ready: ->
    # This is fired when the widget is done being rendered

  onData: (data) ->
    $('body').css(
      background: "black url(#{data.image}?wid=1280&hei=960) no-repeat"
      backgroundSize: '100%'
    )
    # Handle incoming data
    # You can access the html node of this widget with `@node`
    # Example: $(@node).fadeOut().fadeIn() will make the node flash each time data comes in.
