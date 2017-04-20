# # KnobView
#
# This class implements a Backbone View which can be bound to a DOM
# element to turn it into a rotatable, analogue knob.
define(['backbone', 'jquery'], (Backbone, $) ->
  KnobView = Backbone.View.extend({
    events:
      "mousedown": "mousedown"
      "dragstart": "dragstart"

    # The class is instantiated with a params object with the
    # following (optional) properties
    #
    # * `degMin`: The minimum angle which the knob can be turned to (where
    # 0 degrees is defined as 9 o'clock on a clock face). Default: -45 degrees.
    # * `degMax`: The minimum angle which the knob can be turned to. Default: 225 degrees.
    # * `valueMin`: The minimum allowed value of the knob. Default: 0.
    # * `valueMax`: The maximum allowed value of the knob. Default: 1.
    # * `value`: The initial value of the knob. Default: 0.5.
    # * `distanceMax`: The number of pixels of mouse movement
    # corresponding to a full rotation of the knob. Default: 200px.
    initialize: (params) ->
      @knob = $(params.el)
      @degMin = params.degMin || -45
      @degMax = params.degMax || 225
      @valueMin = params.valueMin || 0
      @valueMax = params.valueMax || 1
      @value = params.initial_value || 0.5
      @distanceMax = params.distanceMax || 200

      this.setValue(@value)

    # To prevent the Knob element being dragged instead of turned
    # we prevent the default drag behaviour
    dragstart: (e) ->
      e.preventDefault()

    # On a mousedown event we grab the location of the mouse cursor
    # and the value at the time the rotation starts to allow smooth
    # movement of the knob from any clicked position. We also bind two
    # other events for mousemove and mouseup.
    mousedown: (e) ->
      @valueOnMouseDown = @value
      @cursorLocationOnMouseDown = {x: e.pageX, y: e.pageY}

      $(document).on('mousemove.rem', this.mousemove)
      $(document).on('mouseup.rem', this.removeEvents)

    removeEvents: ->
      # jQuery namespaces are used to clear the events when a mouseup
      # event occurs anywhere in the document
      $(document).off('.rem')

    # When the mouse is moved we calculate the distance it has moved
    # in the y-axis and translate this into values.
    mousemove: (e) =>
      distance = this.calculateDistance(e.pageX, e.pageY)
      value = this.distanceToValue(distance)
      this.setValue(@valueOnMouseDown + value)

    calculateDistance: (x,y) ->
      return @cursorLocationOnMouseDown.y - y

    distanceToValue: (distance) ->
      distance = Math.min(distance, @distanceMax)
      value = (distance / @distanceMax) * (@valueMax - @valueMin)
      return value

    valueToDeg: (value) ->
      return @degMin + ( (value / (@valueMax - @valueMin)) * this.deltaDeg() )

    deltaDeg: ->
      return (@degMax - @degMin)

    setValue: (value) ->
      # Setting the value of the knob requires testing the allowed
      # limits ...
      value = @valueMax if (value > @valueMax)
      value = @valueMin if (value < @valueMin)

      @value = value

      # ... rotating the div ...
      this.setKnobRotation(this.valueToDeg(value))

      # ... and triggering a custom event.
      this.trigger('valueChanged', value)
      return true

    # Rotating the knob is achieved with a CSS transform. As this
    # application targets recent versions of webkit only we are safe
    # to use the `-webkit-transform` property. The angle conventions
    # used for CSS transforms is 90 degrees rotated from the one we
    # use in our calculations, so we account for that here.
    setKnobRotation: (deg) ->
      @knob.css('-webkit-transform','rotate('+(deg-90)+'deg)')

  })
)
