atom = require './atom'
{makeWorld, PlayerShip} = require './world'

TAU = Math.PI*2

class Game extends atom.Game
  constructor: (@world) ->
    super()
    @bind()
    atom.context.fillStyle = 'black'
    atom.context.fillRect 0, 0, atom.canvas.width, atom.canvas.height

  bind: ->
    atom.input.bind atom.button.LEFT, 'shoot'
    atom.input.bind atom.key.W, 'forward'
    atom.input.bind atom.key.S, 'back'
    atom.input.bind atom.key.A, 'left'
    atom.input.bind atom.key.D, 'right'
  
  update: (dt) -> @world.update dt

  draw: ->
    ctx = atom.context
    ctx.fillStyle = 'rgba(0,0,0,0.2)'
    ctx.fillRect 0,0, atom.canvas.width, atom.canvas.height
    data = ctx.getImageData(0, 0, atom.canvas.width, atom.canvas.height)
    @world.draw()

sock = new SockJS 'http://localhost:8008/sock'
sock.onopen = ->
  console.warn 'connected'

game = null

sock.onmessage = (msg) ->
  msg = JSON.parse msg.data
  console.log msg

  if msg.siteId
    world = makeWorld msg.siteId, msg.data
    game = new Game world

    #player = new PlayerShip atom.canvas.width / 2, atom.canvas.height / 2

    game.run()

    if window?
      window.game = game

      window.onblur = game.stop()
      window.onfocus = game.run()

