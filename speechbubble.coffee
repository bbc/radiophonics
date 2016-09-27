# # SpeechBubbleView
#
# This class implements a Backbone View which can be bound to the DOM
# elements representing the speech bubbles (toggle-able switches with
# a hover state)
define(['backbone', 'jquery'], (Backbone, $) ->
  SpeechBubbleView = Backbone.View.extend({
    initialize: () ->
      @state = 0

    events:
      "mouseover": "mouseOver"
      "mouseout": "mouseOut"
      "click": "toggle"

    toggle: ->
      if (@state == 0)
        @state = 1
        this.turnOn()
      else
        this.turnOff()
        @state = 0

    mouseOver: () ->
      $(@el).removeClass('hover').addClass('hover')

    mouseOut: () ->
      $(@el).removeClass('hover')

    turnOn: () ->
      $(@el).removeClass('hover')
      $(@el).removeClass('off').addClass('on')
      this.trigger('on')

    turnOff: () ->
      $(@el).removeClass('hover')
      $(@el).removeClass('on').addClass('off')
      this.trigger('off')
  })
)
