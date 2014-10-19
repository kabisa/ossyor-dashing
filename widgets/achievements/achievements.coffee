class Dashing.Achievements extends Dashing.Widget
  ready: ->
    @shown = 0
    setInterval(
      @scrollAchievements
      15000
    )

  scrollAchievements: =>
    amount = @get('achievements.length')
    if @shown < amount - 1
      @shown += 1
    else
      @shown = 0
    $(@node).find('.achievement:first').css(marginTop: "-#{(@shown * 4)}em")

