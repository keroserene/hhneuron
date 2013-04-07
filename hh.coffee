# hodgkin-huxley simulation.
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

C_m = 1.0  # micro-farads per square cm.

# Obtain the steady state
steady = (gate, v) =>
  a = gate.alpha v
  a / (a + gate.beta v)

steady = (gate, v) ->
  [alpha, beta] = gate v
  alpha / (alpha + beta)

# computeGate = (fun, v) ->
  # fun (v, alpha, beta)

updateGate = (gate, v, alpha, beta) ->
  delta = ((alpha v) * (1.0 - gate)) - ((beta v) * gate)
  gate + delta

# Empirically determined steady-state rate constants via Hodgkin and Huxley.
updateN = (n, v) ->
  updateGate(n, v,
    (v) -> 0.01 * (10 - v) / Math.exp -v / 80,
    (v) -> 0.125 * Math.exp (-v / 80))

updateM = (m, v) ->
  updateGate(m, v,
    (v) -> 0.1 * (25 - v) / (Math.exp ((25 - v)/10) - 1),
    (v) -> 4.0 * Math.exp (-v / 18))

updateH= (h, v) ->
  updateGate(h, v,
    (v) -> 0.07 * Math.exp (-v / 20),
    (v) -> 1.0 / (Math.exp ((30 - v) / 10) + 1))


# Computes the conductance (reciprocal of resistance) given an equilibrium
# constant and exponents for gating variables m, n, h.
class Neuron
  v: 0  # Current voltage.
  fire: (v) =>
    @v = v
    @m = 0
    @n = 0
    @h = 0
    @computeGateVariables()

  stepVoltage: =>
    # Update gating variables.
    @computeGateVariables()
    v = @v
    # console.log 'lol ' + @m + @n + @h
    # I = (@I_Na @v) + (@I_K @v) + (@I_L @v)
    # gna = @G_Na v
    # gk = @G_Na v
    # gl = @G_Na v
    # G = gna + gk + gl
    # R = 1.0 / G
    # I = gna * (v - 115) + gk * (v + 12.0) + gl * (v - 10.6)
    dV = (@I_Na @v) + (@I_K @v) + (@I_L @v)
    # Calculate resistance and divide.
    @v -= dV * 0.00000001

  computeGateVariables: ->
    [@m, @n, @h] = [updateM(@m, @v), updateN(@m, @v), updateH(@h, @v)]

  I_Na: (v) ->
    @_conductance 115.0, 120.0, ((m, n, h) -> Math.pow(m, 3) * h)
  I_K: (v) ->
    @_conductance -12.0, 36.0, ((m, n, h) -> Math.pow(n, 4))
  I_L: (v) ->
    @_conductance 10.6, 0.3, ((m, n, h) -> 1.0)
  # Calculate current given equilibrium, rate, and factor function.
  _conductance: (Ex, gx, factors) ->
    gx * (factors @m, @n, @h)
    # * (@v - Ex)
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
    neuron.fire 10

    @graphing = setInterval =>
      if @tick > 100
        clearInterval @graphing
      @tick += 1
      v = neuron.stepVoltage()
      @datapoint(@tick, v)
      console.log '[' + @tick + '] ' + v
    , 100

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

  neuron = new Neuron()

  $("#fire").click ->
    graph.fire(neuron)
