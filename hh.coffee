# hodgkin-huxley simulation
# 2013-04-07
# keroserene

width = 950
height = 400

# Graphing SPECification.
SPEC =
  px_top: 5
  margin: 30
  v_px: 3
  t_px: 5
  zero: (height / 2)
  axis_color: "#663366"
  data_color: "#ffccff"
  dt: 0.1

C_m = 1.0  # micro-farads per square cm.

# Empirically determined steady-state rate constant expression
# via Hodgkin and Huxley.
RC =
  N: [((v) -> 0.01 * (10.0 - v) / (Math.exp ((10.0 - v) / 10) - 1.0)),
      ((v) -> 0.125 * Math.exp (-v / 80.0))]

  M: [((v) -> 0.1 * (25.0 - v) / (Math.exp ((25.0 - v) / 10.0) - 1.0)),
      ((v) -> 4.0 * Math.exp (-v / 18.0))]

  H: [((v) -> 0.07 * Math.exp (-v / 20.0)),
      ((v) -> 1.0 / (Math.exp ((30.0 - v) / 10.0) + 1.0))]

steady = (ab, v) ->
  a = ab[0] v
  b = ab[1] v
  a / (a + b)

delta = (ab, v, old) ->
  a = ab[0] v
  b = ab[1] v
  d = (ab[0] v) * (1.0 - old) - (ab[1] v) * old
  d * SPEC.dt

# Computes the conductance (reciprocal of resistance) given an equilibrium
# constant and exponents for gating variables m, n, h.
class Neuron
  v: 0  # Current voltage.
  constructor: (@membrane_potential) ->
  delay: 0
  impulse: 0

  fire: (v) =>
    @n = steady(RC.N, @membrane_potential)
    @m = steady(RC.M, @membrane_potential)
    @h = steady(RC.H, @membrane_potential)
    console.log('steady state: ' + @n + ', ' + @m + ', ' + @h)
    @delay = 10
    @impulse = v

  stepVoltage: =>
    v = @v
    @delay -= 1
    if @delay == 1
      v = @impulse
    @n += delta(RC.N, v, @n)
    @m += delta(RC.M, v, @m)
    @h += delta(RC.H, v, @h)
    dV = (@I_Na @v) + (@I_K v) + (@I_L v)
    console.log('gates: ' + @n + ', ' + @m + ', ' + @h + ' -- v: ' + v)
    v -= dV * SPEC.dt
    @v = v

  I_Na: (v) ->
    @_conductance -115.0, 120.0, ((m, n, h) -> Math.pow(m, 3) * h)
  I_K: (v) ->
    @_conductance 12.0, 36.0, ((m, n, h) -> Math.pow(n, 4))
  I_L: (v) ->
    @_conductance 10.613, 0.3, ((m, n, h) -> 1.0)
  # Calculate current given equilibrium, rate, and factor function.
  _conductance: (Ex, gx, factors) ->
    gx * (factors @m, @n, @h)
  _current: (Ex, gx, factors) ->
    gx * (factors @m, @n, @h) * (@v - Ex)


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
    # Time on X axis, Voltage on the Y axis
    @ctx.strokeStyle = SPEC.axis_color
    @ctx.beginPath()
    @line SPEC.margin, SPEC.zero, SPEC.margin + width, SPEC.zero
    @line SPEC.margin, SPEC.px_top, SPEC.margin, height

    label_voltage = (n) =>
      @ctx.fillText n, SPEC.margin - 20, SPEC.zero - n * SPEC.v_px
    label_ms = (t) =>
      @ctx.fillText t, SPEC.margin + t * SPEC.t_px, SPEC.zero + 10

    for n in [0..120] by 5
      label_voltage n-60
    for t in [0..500] by 5
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
    neuron.fire -20

    @graphing = setInterval =>
      if @tick > 100
        clearInterval @graphing
      @tick += 0.05
      @tick += SPEC.dt
      v = neuron.stepVoltage()
      @datapoint(@tick, v)
    , 3

  line: (x1,y1,x2,y2) =>
    @ctx.moveTo x1, y1
    @ctx.lineTo x2, y2
    @ctx.stroke()

  datapoint: (t, v) =>
    @ctx.lineTo(SPEC.margin + t * SPEC.t_px, SPEC.zero - v * SPEC.v_px)
    @ctx.stroke()

$ ->
  # Entry point.
  canvas = $("#pulse")[0]
  graph = new Graph canvas
  graph.init()

  neuron = new Neuron 0

  $("#fire").click ->
    graph.fire(neuron)
