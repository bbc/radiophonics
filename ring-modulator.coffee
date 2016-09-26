# # Ring Modulator
#
# [Ring Modulation](http://en.wikipedia.org/wiki/Ring_modulation) was
# one of the most recognisable effects used by the Radiophonic
# Workshop. It was the effect used to create the voices of both the
# Cybermen and The Daleks for Dr Who.
#
# A simple way to achieve a Ring Modulation effect is to simply
# multiply the input signal by the carrier signal. This approach
# doesn't allow for the characteristic distortion sound that was
# present in early analogue ring modulators which used a "ring" of
# diodes to achieve the multiplication of the signals.
#
# ![Circuit diagram of a traditional ring modulator](/img/circuit_diagram_parker.png "Circuit diagram")
#
# To create a more realistic sound we use the digital model of an
# analogue ring-modulator proposed by Julian Parker. (Julian Parker.
# [A Simple Digital Model Of The Diode-Based
# Ring-Modulator](http://recherche.ircam.fr/pub/dafx11/Papers/66_e.pdf).
# Proc. 14th Int. Conf. Digital Audio Effects, Paris, France, 2011.)
#
# To create the voice of the Daleks the Workshop used a 30Hz sine wave
# as the modulating signal - this was recorded onto a tape loop and
# connected to one input. A microphone was connected to the second
# (carrier) input. The actor could then use the effect live on the set
# of Dr Who. In our demo we allow you to change the frequency (by
# modifying the playback speed of the tape machine). The tape machines
# used originally did not playback at a constant speed - this
# contributed to the distinctive sound of the early Daleks.

# # Preamble
#
# We use jQuery, backbone.js and some custom UI elements (namely a
# [knob](knob.html) a [speech bubble](speechbubble.html) and a
# [switch](switch.html)) in this application. We make these libraries
# available to our application using
# [require.js](http://requirejs.org/)
require(["jquery", "backbone", "knob", "speechbubble", "switch"], ($, Backbone, Knob, SpeechBubble, Switch) ->
  $(document).ready ->

    # # SamplePlayer
    #
    # When a speech bubble is clicked we load a sample using an AJAX
    # request and put it into the buffer of an
    # [AudioBufferSourceNode](https://dvcs.w3.org/hg/audio/raw-file/tip/webaudio/specification.html#AudioBufferSourceNode).
    # The sample is then triggered and looped. The `SamplePlayer`
    # class encapsulates this operation.
    class SamplePlayer extends Backbone.View
      # Instances require the AudioContext in order to create a
      # source buffer.
      constructor: (@context) ->

      play: () ->
        this.stop()
        # Create a new source
        @source = @context.createBufferSource()
        # Assign the loaded buffer to the source
        @source.buffer = @buffer
        # Enable looping
        @source.loop = true
        # Connect the source to the node's destination
        @source.connect(@destination)
        # Play immediately
        @source.start(0)

      stop: ->
        if @source
          # Stop the source from playing
          @source.stop(0)
          @source.disconnect

      # We provide a connect method so that it can
      # be connected to other nodes in a consistant way.
      connect: (destination) ->
        if (typeof destination.node=='object')
          @destination = destination.node
        else
          @destination = destination

      # Make a request for the sound file to load into this buffer,
      # decode it and set the buffer contents
      loadBuffer: (url) ->
        self = this
        request = new XMLHttpRequest()
        request.open('GET', url, true)
        request.responseType = 'arraybuffer'

        request.onload = =>
          onsuccess = (buffer) ->
            self.buffer = buffer
            self.trigger('bufferLoaded')

          onerror = -> alert "Could not load #{self.url}"

          @context.decodeAudioData request.response, onsuccess, onerror

        request.send()

    # # DiodeNode
    #
    # This class implements the diode described in Parker's paper
    # using the Web Audio API's
    # [WaveShaper](https://dvcs.w3.org/hg/audio/raw-file/tip/webaudio/specification.html#WaveShaperNode)
    # node.
    class DiodeNode
      constructor: (@context) ->
        @node = @context.createWaveShaper()

        # three initial parameters controlling the shape of the curve
        @vb = 0.2
        @vl = 0.4
        @h = 1
        this.setCurve()

      setDistortion: (distortion) ->
        # We increase the distortion by increasing the gradient of the
        # linear portion of the waveshaper's curve.
        @h = distortion
        this.setCurve()

      setCurve: ->
        # The non-linear waveshaper curve describes the transformation
        # between an input signal and an output signal. We calculate a
        # 1024-point curve following equation (2) from Parker's paper.
        samples = 1024;
        wsCurve = new Float32Array(samples);

        for i in [0...wsCurve.length]
          # convert the index to a voltage of range -1 to 1
          v = (i - samples/2) / (samples/2)
          v = Math.abs(v)

          if (v <= @vb)
            value = 0
          else if ((@vb < v) && (v <= @vl))
            value = @h * ((Math.pow(v-@vb,2)) / (2*@vl - 2*@vb))
          else
            value = @h*v - @h*@vl + (@h*((Math.pow(@vl-@vb,2))/(2*@vl - 2*@vb)))

          wsCurve[i] = value

        @node.curve = wsCurve

      # We provide a connect method so that instances of this class
      # can be connected to other nodes in a consistant way.
      connect: (destination) ->
        @node.connect(destination)

    # # Connect the graph
    #
    # The following graph layout is proposed by Parker
    #
    # ![Block diagram of diode ring modulator](/img/block_diagram_parker.png "Block diagram")
    #
    # Where `Vin` is the modulation oscillator input and `Vc` is the voice
    # input.
    #
    # Signal addition is shown with a `+` and signal gain by a triangle.
    # The 4 rectangular boxes are non-linear waveshapers which model the
    # diodes in the ring modulator.
    #
    # We implement this graph as in the diagram with the following
    # correspondences:
    #
    # - A triangle is implemented with an [AudioGainNode](https://dvcs.w3.org/hg/audio/raw-file/tip/webaudio/specification.html#AudioGainNode)
    # - Addition is achieved by noting that Web Audio nodes sum their inputs
    # - The diodes are implemented in the DiodeNode class
    #
    context = new AudioContext

    # First we create the objects on the Vin side of the graph
    vIn = context.createOscillator()
    vIn.frequency.value = 30
    vIn.start(0)
    vInGain = context.createGain()
    vInGain.gain.value = 0.5

    # GainNodes can take negative gain which represents phase
    # inversion
    vInInverter1 = context.createGain()
    vInInverter1.gain.value = -1

    vInInverter2 = context.createGain()
    vInInverter2.gain.value = -1

    vInDiode1 = new DiodeNode(context)
    vInDiode2 = new DiodeNode(context)

    vInInverter3 = context.createGain()
    vInInverter3.gain.value = -1

    # Now we create the objects on the Vc side of the graph
    player = new SamplePlayer(context)

    vcInverter1 = context.createGain()
    vcInverter1.gain.value = -1
    vcDiode3 = new DiodeNode(context)
    vcDiode4 = new DiodeNode(context)

    # A gain node to control master output levels
    outGain = context.createGain()
    outGain.gain.value = 4

    # A small addition to the graph given in Parker's paper is a
    # compressor node immediately before the output. This ensures that
    # the user's volume remains somewhat constant when the distortion
    # is increased.
    compressor = context.createDynamicsCompressor()
    compressor.threshold.value = -12

    # Now we connect up the graph following the block diagram above.
    # When working on complex graphs it helps to have a pen and paper
    # handy!

    # First the Vc side
    player.connect(vcInverter1)
    player.connect(vcDiode4)

    vcInverter1.connect(vcDiode3.node)

    # Then the Vin side
    vIn.connect(vInGain)
    vInGain.connect(vInInverter1)
    vInGain.connect(vcInverter1)
    vInGain.connect(vcDiode4.node)

    vInInverter1.connect(vInInverter2)
    vInInverter1.connect(vInDiode2.node)
    vInInverter2.connect(vInDiode1.node)

    # Finally connect the four diodes to the destination via the
    # output-stage compressor and master gain node
    vInDiode1.connect(vInInverter3)
    vInDiode2.connect(vInInverter3)

    vInInverter3.connect(compressor)
    vcDiode3.connect(compressor)
    vcDiode4.connect(compressor)

    compressor.connect(outGain)
    outGain.connect(context.destination)

    # # User Interface

    # A [speech bubble](speechbubble.html) is a simple
    # backbone.js view with a toggle and hover state
    bubble1 = new SpeechBubble(el: $("#voice1"))
    bubble2 = new SpeechBubble(el: $("#voice2"))
    bubble3 = new SpeechBubble(el: $("#voice3"))
    bubble4 = new SpeechBubble(el: $("#voice4"))

    # [Knobs](knob.html) for the oscillator frequency ...
    speedKnob = new Knob(
     el: "#tape-speed"
     initial_value: 30
     valueMin: 0
     valueMax: 2000
    )

    # ... and the distortion control
    distortionKnob = new Knob(
      el: "#mod-distortion",
      initial_value: 1
      valueMin: 0.2
      valueMax: 50
    )

    # Map events that are fired when user interface objects are
    # interacted with to the corresponding parameters in the ring
    # modulator
    distortionKnob.on('valueChanged', (v) =>
      _.each([vInDiode1, vInDiode2, vcDiode3, vcDiode4], (diode) -> diode.setDistortion(v))
    )

    speedKnob.on('valueChanged', (v) =>
      vIn.frequency.value = v
    )

    # For each speech bubble, when clicked we stop any currently
    # playing buffers and play the sample associated with this buffer.
    bubble1.on('on', ->
      _.each([bubble2, bubble3, bubble4], (o) -> o.turnOff() )
      player.loadBuffer("/audio/ringmod_exterminate.wav")
      player.on('bufferLoaded', -> player.play())
    )

    bubble1.on('off', ->
      player.stop()
    )

    bubble2.on('on', ->
      _.each([bubble1, bubble3, bubble4], (o) -> o.turnOff() )
      player.loadBuffer("/audio/ringmod_good-dalek.wav")
      player.on('bufferLoaded', -> player.play())
    )

    bubble2.on('off', ->
      player.stop()
    )

    bubble3.on('on', ->
      _.each([bubble1, bubble2, bubble4], (o) -> o.turnOff() )
      player.loadBuffer("/audio/ringmod_upgrading.wav")
      player.on('bufferLoaded', -> player.play())
    )

    bubble3.on('off', ->
      player.stop()
    )

    bubble4.on('on', ->
      _.each([bubble1, bubble2, bubble3], (o) -> o.turnOff() )
      player.loadBuffer("/audio/ringmod_delete.wav")
      player.on('bufferLoaded', -> player.play())
    )

    bubble4.on('off', ->
      player.stop()
    )

    # # Experimental! Microphone input support
    #
    # This will only work on Chrome Canary builds on OS X and Windows.
    # [HTML5
    # Rocks](http://updates.html5rocks.com/2012/09/Live-Web-Audio-Input-Enabled)
    # has the information you'll need to try this feature out.

    liveInputGain = context.createGain()
    liveInput     = null

    # There's no easy way to feature detect if this is supported so
    # we have to browser detect the version of Chrome
    isLiveInputSupported = ->
      isSupported = false
      browser = $.browser

      if browser.chrome
        majorVersion = parseInt( browser.version.split('.')[0] )
        isSupported  = true if majorVersion >= 23

      isSupported

    getLive = =>
      navigator.webkitGetUserMedia( {audio:true}, gotStream )

    gotStream = (stream) =>
      liveInput = context.createMediaStreamSource( stream )
      liveInput.connect(liveInputGain)
      liveInputGain.connect(vcInverter1)
      liveInputGain.gain.value = 1.0

    class KonamiCode
      constructor: () ->
                    # ↑ ↑ ↓ ↓ ← → ← → B A
        @konami   = [38,38,40,40,37,39,37,39,66,65];
        @keys     = []
        @callback = null
        $(document).keydown( @keydown )
      onPowerup: (callback) =>
        @callback = callback
      keydown: (e) =>
        @keys.push(e.keyCode)
        isCorrectCode = @keys.join(',').indexOf(@konami.join(',')) >= 0
        if isCorrectCode
          @callback() if @callback?
          @keys = []
        else if @keys.length == @konami.length
          @keys = []

    konami = new KonamiCode()
    konami.onPowerup ->
      console.log("powerup")
      activateLiveMicButton()

    activateLiveMicButton = ->
      tapeswitch = new Switch(el: '#live-input')

      tapeswitch.on('off', ->
        liveInputGain.gain.value = 0
      )

      tapeswitch.on('on', ->
        getLive()
      )

  )
