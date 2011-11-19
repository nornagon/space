atom = require './atom'
console.warn atom

TAU = Math.PI*2

class SpaceGame extends atom.Game
  constructor: ->
    super()
    @bind()
    @entities = []
    @deadEntityIDs = []
    atom.context.fillStyle = 'black'
    atom.context.fillRect 0, 0, atom.canvas.width, atom.canvas.height

  addEntity: (e) ->
    @entities.push e

  removeEntity: (e) ->
    @deadEntityIDs.push @entities.indexOf e

  bind: ->
    atom.input.bind atom.button.LEFT, 'shoot'
    atom.input.bind atom.key.W, 'forward'
    atom.input.bind atom.key.S, 'back'
    atom.input.bind atom.key.A, 'left'
    atom.input.bind atom.key.D, 'right'

  update: (dt) ->
    e?.update? dt for e in @entities
    if @deadEntityIDs.length > 0
      # remove dead entities
      @deadEntityIDs.sort_by (a, b) -> b - a
      for id in @deadEntityIDs
        @entities.splice id, 1
  draw: ->
    ctx = atom.context
    ctx.fillStyle = 'rgba(0,0,0,0.2)'
    ctx.fillRect 0,0, atom.canvas.width, atom.canvas.height
    data = ctx.getImageData(0, 0, atom.canvas.width, atom.canvas.height)
    e.draw?() for e in @entities

class Entity
  constructor: ->
    game.addEntity this
  destroy: ->
    game.removeEntity this

class PhysicalEntity extends Entity
  constructor: (@x, @y) ->
    @vx = @vy = 0
    @angle = 0
    super()
  update: (dt) ->
    @x += @vx * dt
    @y += @vy * dt

class Ship extends PhysicalEntity
  constructor: (x, y) ->
    super(x, y)
  draw: ->
    ctx = atom.context
    ctx.strokeStyle = 'rgb(230,0,0)'
    ctx.lineWidth = 2
    ctx.save()
    ctx.translate @x, @y
    ctx.rotate @angle
    ctx.beginPath()
    ctx.moveTo -10, -10
    ctx.lineTo 0, 10
    ctx.lineTo 10, -10
    ctx.closePath()
    ctx.stroke()
    ctx.restore()

class PlayerShip extends Ship
  constructor: (x, y) ->
    super x, y
  update: (dt) ->
    dx = atom.input.mouse.x - @x
    dy = atom.input.mouse.y - @y
    @angle = Math.atan2(dy, dx) - TAU/4
    if atom.input.down 'forward'
      @vx += -Math.sin(@angle) * dt * 0.001
      @vy += Math.cos(@angle) * dt * 0.001
    super(dt)

window?.game = game = new SpaceGame

player = new PlayerShip atom.canvas.width / 2, atom.canvas.height / 2

window.onblur = game.stop()
window.onfocus = game.run()

game.run()
