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
  mV_range: 80
  ms_range: 100
  # mV_px: 5                # Pixels per millivolt.
  # ms_px: 5                # Pixels per millisecond.
  dt: 0.01                # Time per between simulation step.
  stim_delay: 1       # Milliseconds before stimulus begins.
  stim_duration: 30
  axis_color: "#663366"
  data_color: "#ffccff"

SPEC.px_mV = height / SPEC.mV_range
SPEC.px_ms = width / SPEC.ms_range

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

E =         # Reversal potential
  Na: -115.0
  K: 12.0
  L: 10.613

gbar =         # Conductance
  Na: 120.0
  K: 36.0
  L: 0.3

steady = (gate, v) ->
  a = alpha[gate] v
  b = beta[gate] v
  a / (a + b)
delta = (gate, v, old) ->
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
    @impulse = parseFloat(v)/SPEC.stim_duration

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
    $('#n').text(@n.toFixed(8))
    $('#m').text(@m.toFixed(8))
    $('#h').text(@h.toFixed(8))

    I_Na = Math.pow(@m, 3) * @h * @current 'Na'
    I_K = Math.pow(@n, 4) * @current 'K'
    I_L = @current 'L'

    # dV = (@I_Na v) + (@I_K v) + (@I_L v)
    dV = I_Na + I_K + I_L
    # console.log('gates: ' + @n + ', ' + @m + ', ' + @h + ' -- v: ' + v)
    # console.log('currents: ' + I_Na + ', ' + I_K + ', ' + I_L + ' -- v: ' + v)
    v -= dV * SPEC.dt
    @v = v


# Canvas representation
class Graph
  tick: 0
  ctx: null
  graphing: null

  constructor: (@canvas) ->
    @ctx = canvas.getContext "2d"
    @ctx.fillStyle = "#ffffff"
    @ctx.lineWidth = 1

  init: =>
    # Build graph. Time on X axis, Voltage on the Y axis.
    @ctx.strokeStyle = SPEC.axis_color
    @ctx.beginPath()
    @line SPEC.margin, SPEC.zero, SPEC.margin + width, SPEC.zero
    @line SPEC.margin, SPEC.px_top, SPEC.margin, height
    label_voltage = (n) =>
      @ctx.fillText n, SPEC.margin - 20, SPEC.zero - n * SPEC.px_mV
    label_ms = (t) =>
      @ctx.fillText t, SPEC.margin + t * SPEC.px_ms, SPEC.zero + 10
    for n in [0..SPEC.mV_range] by 5
      label_voltage (n - SPEC.mV_range / 2)
    for t in [0..SPEC.ms_range] by 5
      label_ms t
    @ctx.strokeStyle = SPEC.data_color
    @ctx.closePath()
    true

  # Begin an action potential simulation.
  # Inject is the number of mV applied to the neuron.
  fire: (neuron) =>
    @ctx.beginPath()
    @ctx.moveTo SPEC.margin, SPEC.zero
    @tick = 0.0
    # Initializes membrane voltage.
    neuron.fire $('#stimulus').val()
    @graphing = setInterval =>
      if @tick > SPEC.ms_range
        clearInterval @graphing
      @tick += 1
      v = neuron.stepVoltage()
      @datapoint(@tick, v)
    , 1

  line: (x1,y1,x2,y2) =>
    @ctx.moveTo x1, y1
    @ctx.lineTo x2, y2
    @ctx.stroke()

  datapoint: (t, v) =>
    @ctx.lineTo(SPEC.margin + t * SPEC.px_ms, SPEC.zero - v * SPEC.px_mV)
    @ctx.stroke()

$ ->
  canvas = $("#pulse")[0]
  graph = new Graph canvas
  graph.init()
  neuron = new Neuron 0
  $("#stimulus").val(20)

  $("#fire").click ->
    graph.fire(neuron)
