module.exports = atom = {}
atom.input =
  _bindings: {}
  _down: {}
  _pressed: {}
  _released: []
  mouse: { x:0, y:0 }

  bind: (key, action) ->
    @_bindings[key] = action

  onkeydown: (e) ->
    action = @_bindings[eventCode e]
    return unless action

    @_pressed[action] = true unless @_down[action]
    @_down[action] = true

    e.stopPropagation()
    e.preventDefault()

  onkeyup: (e) ->
    action = @_bindings[eventCode e]
    return unless action
    @_released.push action
    e.stopPropagation()
    e.preventDefault()

  clearPressed: ->
    for action in @_released
      @_down[action] = false
    @_released = []
    @_pressed = {}

  pressed: (action) -> @_pressed[action]
  down: (action) -> @_down[action]

  onmousemove: (e) ->
    @mouse.x = e.pageX
    @mouse.y = e.pageY
  onmousedown: (e) -> @onkeydown(e)
  onmouseup: (e) -> @onkeyup(e)
  onmousewheel: (e) ->
    @onkeydown e
    @onkeyup e
  oncontextmenu: (e) ->
    if @_bindings[atom.button.RIGHT]
      e.stopPropagation()
      e.preventDefault()

document.onkeydown = atom.input.onkeydown.bind(atom.input)
document.onkeyup = atom.input.onkeyup.bind(atom.input)

atom.button =
  LEFT: -1
  MIDDLE: -2
  RIGHT: -3
  WHEELDOWN: -4
  WHEELUP: -5
atom.key =
  TAB: 9
  ENTER: 13
  ESC: 27
  SPACE: 32
  LEFT_ARROW: 37
  UP_ARROW: 38
  RIGHT_ARROW: 39
  DOWN_ARROW: 40

for c in [65..90]
  atom.key[String.fromCharCode c] = c

eventCode = (e) ->
  if e.type == 'keydown' or e.type == 'keyup'
    e.keyCode
  else if e.type == 'mousedown' or e.type == 'mouseup'
    switch e.button
      when 0 then atom.button.LEFT
      when 1 then atom.button.MIDDLE
      when 2 then atom.button.RIGHT
  else if e.type == 'mousewheel'
    if e.wheel > 0
      atom.button.WHEELUP
    else
      atom.button.WHEELDOWN

atom.canvas = document.getElementsByTagName('canvas')[0]
atom.canvas.style.position = "absolute"
atom.canvas.style.top = "0"
atom.canvas.style.left = "0"
atom.context = atom.canvas.getContext '2d'

atom.canvas.onmousemove = atom.input.onmousemove.bind(atom.input)
atom.canvas.onmousedown = atom.input.onmousedown.bind(atom.input)
atom.canvas.onmouseup = atom.input.onmouseup.bind(atom.input)
atom.canvas.onmousewheel = atom.input.onmousewheel.bind(atom.input)
atom.canvas.oncontextmenu = atom.input.oncontextmenu.bind(atom.input)

window.onresize = (e) ->
  atom.canvas.width = window.innerWidth
  atom.canvas.height = window.innerHeight
  atom.width = atom.canvas.width
  atom.height = atom.canvas.height
window.onresize()

class Game
  constructor: ->
    @fps = 30
  update: (dt) ->
  draw: ->
  run: ->
    @last_step = Date.now()
    @loop_interval = setInterval =>
      @step()
    , 1000/@fps
  stop: ->
    clearInterval @loop_interval if @loop_interval?
    @loop_interval = null
  step: ->
    now = Date.now()
    dt = now - @last_step
    @last_step = now
    @update dt/1000
    @draw()
    atom.input.clearPressed()
atom.Game = Game
