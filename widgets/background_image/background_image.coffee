class Dashing.BackgroundImage extends Dashing.Widget

  constructor: ->
    super
    @img = 1

  ready: ->
    # This is fired when the widget is done being rendered

  onData: (data) ->
    newImage = "#{data.image}?wid=1280&hei=960"
    if @img is 1
      $(@node).find('.image-background').css(
        backgroundImage: "url(#{newImage}), radial-gradient(ellipse at center, hsl(0,0%,50%) 0%,hsl(0,0%,0%) 100%)"
      )
      setTimeout(
        => $(@node).find('.image-foreground').addClass('hidden')
        3000
      )
      @img = 2
    else
      $(@node).find('.image-foreground').css(
        backgroundImage: "url(#{newImage}), radial-gradient(ellipse at center, hsl(0,0%,50%) 0%,hsl(0,0%,0%) 100%)"
      )
      setTimeout(
        => $(@node).find('.image-foreground').removeClass('hidden')
        3000
      )
      @img = 1

