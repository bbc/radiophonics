#
# ![Block diagram of the Electronic Gunfire Effects Generator](/img/gunfire_block_diagram.png "Block diagram")
#
# # Preamble
#
# We use jQuery, backbone.js and some custom UI elements (namely a
# [knob](knob.html) and a [switch](switch.html)) in this
# application. We make these libraries available to our application
# using [require.js](http://requirejs.org/)
require(["jquery", "backbone", "knob", "switch"], ($, Backbone, Knob, Switch) ->
  $(document).ready ->
  
	# This BufferSource plays a white noise signal read in from a wav file
	# The same effect could be achived using a Javascript Node with the following code
	# to generate random numbers in a range of -1 - 1
  #
  #     class WhiteNoise
  #   
  #       constructor: (context) ->
  #         self = this
  #         @context = context
  #         @node = @context.createJavaScriptNode(1024, 1,2)
  #         @node.onaudioprocess = (e) -> self.process(e)
  #
  #       process: (e) ->
  #         data0 = e.outputBuffer.getChannelData(0)
  #         data1 = e.outputBuffer.getChannelData(1)
  #         for i in [0..data0.length-1]
  #           data0[i] = ((Math.random() * 2) - 1)
  #           data1[i] = data0[i]
    class Player
      constructor: (@url) ->
        this.loadBuffer()
        @source = audioContext.createBufferSource()
      play: ->
        if @buffer
          # Set the buffer of a new AudioBufferSourceNode equal to the
          # samples loaded by `loadBuffer`
          
          @source.buffer = @buffer
          @source.loop = true
          @source.start 0
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
            self.play()

          onerror = -> alert "Could not load #{@url}"

          audioContext.decodeAudioData request.response, onsuccess, onerror

        request.send()
        
    # this class uses a gain node to generate a volume ramp at specific times to simulate the attack and release time of the gunshot
    class Envelope
      constructor: () ->
        self = this
        @node = audioContext.createGainNode()
        @node.gain.value = 0
      
      addEventToQueue: () ->
        #Set gain to 0 "now"
        @node.gain.linearRampToValueAtTime(0, audioContext.currentTime);
        #Attack - ramp to 1 in 0.0001ms
        @node.gain.linearRampToValueAtTime(1, audioContext.currentTime + 0.001);
        #Decay - ramp to 0.3 over 100ms
        @node.gain.linearRampToValueAtTime(0.3, audioContext.currentTime + 0.101);
        #Release - ramp down to 0 over 500ms
        @node.gain.linearRampToValueAtTime(0, audioContext.currentTime + 0.500);

	  # Now we create and connect the noise to the envelope generators
	  # so that they can be triggered by the timing node
	  # we also create 4 voices to allow shots to overlap
    audioContext = new AudioContext
    # Create the noise source
    noise = new Player("/audio/white_noise.wav")
    
    # We create 4 instances of the envelope class to provide 4 seperate voices
    # this is necessary as if the raite of fire is very fast the envelope will not 
    # have time to reach zero before being triggered again
    voice1 = new Envelope()
    voice2 = new Envelope()
    voice3 = new Envelope()
    voice4 = new Envelope()
    
    #Connect the noise source to the 4 voices
    noise.source.connect(voice1.node)
    noise.source.connect(voice2.node)
    noise.source.connect(voice3.node)
    noise.source.connect(voice4.node)
    
    # connect the voice outputs to a filter to allow a simulation of distance
    filter = audioContext.createBiquadFilter()
    # set to low pass
    filter.type = 0
    filter.Q.value = 1
    filter.frequency.value = 800
    
    # connect the voices to the filter
    voice1.node.connect(filter)
    voice2.node.connect(filter)
    voice3.node.connect(filter)
    voice4.node.connect(filter)
  	
  	# connect the filter to a master gain node
    gainMaster = audioContext.createGainNode()  
    gainMaster.gain.value = 5
    filter.connect(gainMaster)
    
    # connect the gain node to the output destination
    gainMaster.connect(audioContext.destination)
    
    # a function to select the next voice and queue the event
    voiceSelect = 0
    fireRate = 1000
    intervalTimer = 0
    
    schedule = ()  ->
      voiceSelect++
      if voiceSelect > 4 then voiceSelect = 1
      if voiceSelect == 1 then voice1.addEventToQueue()
      if voiceSelect == 2 then voice2.addEventToQueue()
      if voiceSelect == 3 then voice3.addEventToQueue()
      if voiceSelect == 4 then voice4.addEventToQueue()
    
    # set up the controls
    volume_knob = new Knob(el: '#volume')
    rate_of_fire_knob = new Knob(el: '#rate-of-fire')
    distance_knob = new Knob(el: '#distance')
    multi_fire_switch = new Switch(el: '#multi-fire')
    trigger = $('#trigger')
    
    # set the rapid fire rate
    multi_fire_switch.on('on', =>
      schedule()
      intervalTimer = setInterval (-> schedule()), fireRate
    )
    # clear the rapid fire function
    multi_fire_switch.on('off', =>
      clearInterval(intervalTimer)
    )
    
    # set the master gain value
    volume_knob.on('valueChanged', (v) =>
      gainMaster.gain.value = v * 20
    )

    # set the filter frequency
    distance_knob.on('valueChanged', (v) =>
      filter.frequency.value = ((v * 800) + 100)
    )
    
    # change the rate of fire
    rate_of_fire_knob.on('valueChanged', (v) =>
      fireRate = (v + 1) * 150
      clearInterval(intervalTimer)
      intervalTimer = setInterval (-> schedule()), fireRate
      
    )
    
    # trigger a single shot
    trigger.click(->schedule())
)
