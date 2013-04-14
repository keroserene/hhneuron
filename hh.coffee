# hodgkin-huxley simulation
# 2013-04-07
# keroserene

# HTML5 canvas resolution.
width = 500
height = 400

# General simulation constants.
SPEC =
  px_top: 5
  margin: 30
  zero: (height / 2)
  threads: 100
  mV_range: 60
  ms_range: 10
  dt: 0.001                # Time per between simulation step.
  stim_delay: 1       # Milliseconds before stimulus begins.
  stim_duration: 20
  axis_color: "#664466"
  data_color: "#ffccff"

C_m = 1.0  # micro-farads / sq-cm.

# Empirically determined steady-state rate constant expression.
alpha =
  N: (v) -> 0.01 * (10.0 - v) / (Math.exp ((10.0 - v) / 10) - 1.0)
  M: (v) -> 0.1 * (25.0 - v) / (Math.exp ((25.0 - v) / 10.0) - 1.0)
  H: (v) -> 0.07 * Math.exp (-v / 20.0)

beta =
  N: (v) -> 0.125 * Math.exp (-v / 80.0)
  M: (v) -> 4.0 * Math.exp (-v / 18.0)
  H: (v) -> 1.0 / (Math.exp ((30.0 - v) / 10.0) + 1.0)

E =            # Reversal potential
  Na: -115.0
  K: 12.0
  L: 10.613

gbar =         # Conductance
  Na: 120.0
  K: 36.0
  L: 0.3

steady = (gate, v) ->   # Steady-state gating-variable value.
  a = alpha[gate] v
  a / (a + beta[gate] v)

delta = (gate, v, old) ->   # Gate variable change step based on mV.
  d = (alpha[gate] v) * (1.0 - old) - (beta[gate] v) * old
  d * SPEC.dt

# Computes the conductance (reciprocal of resistance) given an equilibrium
# constant and exponents for gating variables m, n, h.
class Neuron
  v: 0  # Current voltage.
  constructor: (@membrane_potential) ->
  delay: 0
  impulse: 0
  current: (ion) -> gbar[ion] * (@v - E[ion])

  # Try action potential with |v| millivolts.
  fire: (v) =>
    @v = 0
    @n = steady('N', @membrane_potential)
    @m = steady('M', @membrane_potential)
    @h = steady('H', @membrane_potential)
    @delay = parseInt SPEC.stim_duration
    @impulse = parseFloat(v) / parseFloat(SPEC.stim_duration)

  # Single step of the simulation.
  stepVoltage: =>
    v = @v
    # Apply stimulus in early timesteps.
    if @delay > 0
      v += @impulse if @delay < SPEC.stim_duration - SPEC.stim_delay
      @delay -= 1
    @n += delta('N', v, @n)
    @m += delta('M', v, @m)
    @h += delta('H', v, @h)
    # $('#n').text(@n.toFixed(8))
    # $('#m').text(@m.toFixed(8))
    # $('#h').text(@h.toFixed(8))
    I_Na = Math.pow(@m, 3) * @h * @current 'Na'
    I_K = Math.pow(@n, 4) * @current 'K'
    I_L = @current 'L'
    dV = I_Na + I_K + I_L
    v -= dV * SPEC.dt
    v = 40 if v > 40
    v = -40 if v < -40
    @v = v


# Canvas representation
class Graph
  tick: 0
  ctx: null
  graphing: null
  red: 255
  green: 128
  blue: 255
  neuron: null

  constructor: (@canvas) ->
    @ctx = canvas.getContext "2d"
    @ctx.fillStyle = "#ffffff"
    @ctx.lineWidth = 1
    @init()

  init: =>
    # Build graph. Time on X axis, Voltage on the Y axis.
    @px_mV = height / SPEC.mV_range
    @px_ms = width / SPEC.ms_range
    @ctx.strokeStyle = SPEC.axis_color
    @ctx.fillStyle = SPEC.axis_color
    @ctx.beginPath()
    @line SPEC.margin, SPEC.zero, SPEC.margin + width, SPEC.zero
    @line SPEC.margin, SPEC.px_top, SPEC.margin, height
    label_voltage = (n) =>
      @ctx.fillText n, SPEC.margin - 20, SPEC.zero - n * @px_mV
    label_ms = (t) =>
      @ctx.fillText t, SPEC.margin + t * @px_ms, SPEC.zero + 10
    for n in [0..SPEC.mV_range] by 5
      label_voltage (n - SPEC.mV_range / 2)
    for t in [0..SPEC.ms_range] by 1
      label_ms t
    @ctx.closePath()
    # Start a bunch of render threads for speed!
    setInterval @graphStep, 0  for [1..SPEC.threads]

  # Begin an action potential simulation.
  # Inject is the number of mV applied to the neuron.
  fire: (neuron) =>
    # Clean up any interrupted action potential signals.
    if @neuron
      @ctx.strokeStyle = rgb(60,20,20)
      @ctx.stroke()
      # @ctx.closePath()
    else
      @tick = 0.0
      @ctx.beginPath()
      @ctx.moveTo SPEC.margin, SPEC.zero
    neuron.fire $('#stimulus').val()
    @neuron = neuron

  graphStep: () =>
    if not @neuron
      return
    @tick += SPEC.dt
    factor = Math.max(0, 1 - 0.8*(@tick / parseFloat(SPEC.ms_range)))
    color = rgb(@red * factor, @green * factor, @blue * factor)
    @ctx.strokeStyle = color
    v = @neuron.stepVoltage()
    if @tick > SPEC.ms_range
      @ctx.strokeStyle = rgb(60,30,60)
      @neuron = null
    @datapoint(@tick, v)

  line: (x1,y1,x2,y2) =>
    @ctx.moveTo x1, y1
    @ctx.lineTo x2, y2
    @ctx.stroke()

  datapoint: (t, v) =>
    @ctx.lineTo(SPEC.margin + t * @px_ms, SPEC.zero - v * @px_mV)
    @ctx.stroke()

rgb = (r, g, b) ->
  'rgb(' + parseInt(r) + ', ' + parseInt(g) + ', ' + parseInt(b) + ')'

editStimulus = (v) ->
  $('#stimulus').val(parseFloat(v))

changeStimulus = (dV) ->
  o = $('#stimulus')
  editStimulus(parseFloat($('#stimulus').val()) + dV)
  o.focus()

$ ->
  canvas = $("#pulse")[0]
  graph = new Graph canvas
  neuron = new Neuron 0
  $("#stimulus").val(20)
  $("#fire").click ->
    graph.fire(neuron)
  $(document).keydown (e) ->
    switch e.keyCode
      when 38
        changeStimulus(1)
        false
      when 40
        changeStimulus(-1)
        false
      when 13
        graph.fire(neuron)
        false
      else
        true
