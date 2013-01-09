# # SwitchView
#
# This class implements a Backbone View that can be bound to a DOM
# element to turn it into a toggle switch.
define(['backbone'], ->
  class SwitchView extends Backbone.View
    # The switch defaults to off (0).
    initialize: () ->
      @count = 0
      @states = @options.states || ['off', 'on']
      @applyState()

    # When the switch is `click`ed ...
    events:
      "click": "incrementState"

    # Get the current state of the switch
    currentState: ->
      @states[@count % @states.length]

    # Apply the current state to the DOM
    applyState: ->
      $(this.el).removeClass(@states.join(' ')).addClass(@currentState())

    # ... increment the state counter and trigger the new state
    incrementState: ->
      @count = @count + 1
      @applyState()
      this.trigger(@currentState())
)