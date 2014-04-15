# # Tape Loops
#
# In the early days of the Radiophonics Workshop pieces of music were
# painstakingly composed a note at a time by recording and splicing
# together pieces of tapes in loops. In [this
# video](http://www.youtube.com/watch?v=NDX_CS3NsTk) you can see Delia
# Derbyshire explaining the process and showing one of the more tricky
# aspects - that of "beat matching" the individual loops so that they
# are in sync.
#
# ![Tape machine](/img/tapemachine.jpg "A photo of a tapemachine from the Science Museum Oramics Exhibit")
#
# This demo is a simulation of three tape machines with variable speed
# controls that have to be triggered in time to build up a simple
# composition. It is a simple example of the use of the Web Audio
# API's [AudioBufferSourceNode](https://dvcs.w3.org/hg/audio/raw-file/tip/webaudio/specification.html#AudioBufferSourceNode)
#
# This application is a simulation of three tape loop machines with
# variable speed controls using the Web Audio API.

# # Preamble
#
# We use jQuery, backbone.js and some custom UI elements (namely a
# [knob](knob.html) and a [switch](switch.html)) in this application.
# We make these libraries available to our application using
# [require.js](http://requirejs.org/)
require(["jquery", "backbone", "knob", "switch"], ($, Backbone, Knob, Switch) ->
  $(document).ready ->

    # # Player
    #
    # AudioBufferSourceNode's work in a slightly counter-intuitive way
    # for performance reasons. Once a sound has been triggered with a
    # 'start' message, it cannot be re-triggered. The
    # [FAQ](http://updates.html5rocks.com/2012/01/Web-Audio-FAQ) on
    # [HTML5 Rocks](http://www.html5rocks.com/) discusses the reasons
    # behind this. To make the sample player more natural to work with
    # in this application we wrap a AudioBufferSourceNode in a custom
    # class.
    class Player
      constructor: (@url) ->
        this.loadBuffer()

        # Set the default playback speed
        this.setBaseSpeed(1)
        this.setSpeedFine(1)

      play: ->
        if @buffer
          # Set the buffer of a new AudioBufferSourceNode equal to the
          # samples loaded by `loadBuffer`
          @source = context.createBufferSource()
          @source.buffer = @buffer
          @source.connect context.destination
          @source.loop = true
          this.setSpeed()

          # Trigger the source to play immediately
          @source.start 0

      stop: ->
        if @buffer && @source
          # Stop the sample playback immediately
          @source.stop 0

      setBaseSpeed: (speed) ->
        @base_speed = speed
        this.setSpeed()

      setSpeedFine: (speed) ->
        @fine_speed = speed
        this.setSpeed()

      # The playback speed is a combination of the "base speed"
      # (normal or double speed playback) and a "fine speed" control.
      setSpeed: ->
        if @source
          @source.playbackRate.value = @base_speed * @fine_speed

      # Load the samples from the provided `url`, decode and store in
      # an instance variable.
      loadBuffer: ->
        self = this

        request = new XMLHttpRequest()
        request.open('GET', @url, true)
        request.responseType = 'arraybuffer'

        # Load the decoded sample into the buffer if the request is successful
        request.onload = =>
          onsuccess = (buffer) ->
            self.buffer = buffer

          onerror = -> alert "Could not load #{@url}"

          context.decodeAudioData request.response, onsuccess, onerror

        request.send()

    # # TapeMachine
    #
    # A class that, given a DOM element `el` and a `Player` simulates
    # a tape machine.
    #
    class TapeMachine
      constructor: (@el, @player) ->
        @setupSpeedToggle()
        @setupFineSpeed()
        @setupPlayStop()

      # The tape speed switch toggles the base speed of the player
      # between normal speed half speed.
      setupSpeedToggle: () ->
        # Bind a [Switch](switch.html) to the `double-speed`
        # element within the current `el`
        speed_toggle = new Switch(el: $(@el).find('.speed'), states: ['normal', 'half'])

        # The [switch](switch.html) fires `normal` and `half` events. We bind
        # these events to the `setBaseSpeed` method of the player.
        speed_toggle.on('normal', => @player.setBaseSpeed(1))
        speed_toggle.on('half', => @player.setBaseSpeed(0.5))

      # Attach a [Knob](knob.html) to the fine speed control to
      # vary the playback speed by ±3%
      setupFineSpeed: () ->
        fine_speed_control = new Knob(
          el: $(@el).find('.fine-speed')
          initial_value: 1
          valueMin: 0.97
          valueMax: 1.03
        )

        # The [Knob](knob.html) triggers `valueChanged` events
        # when turned. We send the value to the `setSpeedFine` method
        # on the player
        fine_speed_control.on('valueChanged', (v) =>
          @player.setSpeedFine(v)
        )

      # A switch to toggle the play state of the machine
      setupPlayStop: () ->
        play_stop_control = new Switch(el: $(@el).find('.play'))
        play_stop_control.on('on', => @player.play())
        play_stop_control.on('off', => @player.stop())

    # # Application Setup

    # Create an audio context for our application to exist within.
    context = new AudioContext

    # Instantiate three separate players with the three loops.
    player1 = new Player('/audio/delia_loop_01.ogg')
    player2 = new Player('/audio/delia_loop_02.ogg')
    player3 = new Player('/audio/delia_loop_03.ogg')

    # Setup the UI
    new TapeMachine('#machine1', player1)
    new TapeMachine('#machine2', player2)
    new TapeMachine('#machine3', player3)
  )
