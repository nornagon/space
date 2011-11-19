atom = if process.title is 'browser' then require './atom'

exports.Entity = class Entity
  constructor: (@x, @y) ->
    @vx = @vy = 0
    @angle = 0

  destroy: ->
    @killme = yes

  update: (dt) ->
    @x += @vx * dt
    @y += @vy * dt

  draw: ->
    # For testing.
    ctx = atom.context
    ctx.strokeStyle = 'rgb(255,255,255)'
    ctx.lineWidth = 2
    ctx.save()
    ctx.translate @x, @y
    ctx.rotate @angle
    ctx.beginPath()
    ctx.moveTo -10, -10
    ctx.lineTo -10, 10
    ctx.lineTo 10, 10
    ctx.lineTo 10, -10
    ctx.closePath()
    ctx.stroke()
    ctx.restore()

  load: (data) ->
    {@x, @y, @vx, @vy, @angle} = data

  export: ->
    {@x, @y, @vx, @vy, @angle}

  type: 'Entity'

exports.Ship = class Ship extends Entity
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

  load: (data) ->
    super data

  type: 'Ship'

exports.PlayerShip = class PlayerShip extends Ship
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

types = {Entity, Ship, PlayerShip}

exports.makeWorld = (siteId, data) ->
  nextId = 1

  # Map of ID -> Entity
  entities = {}

  # list of entity IDs 
#  dirty = []

  readData = (d) ->
    e = entities[d.id] or new types[d.type]
    e.id = d.id
    e.load d
    entities[e.id] = e

  if data
    readData d for d in data

  add: (e) ->
    throw new Error 'entity already in world' if e.id
    e.id = "#{siteId}_#{nextId++}"
    entities[e.id] = e

  removeEntity: removeEntity = (e) ->
    if e.id
      delete entities[e.id]
      delete e.id

  update: (dt) ->
    for id, e of entities
      e.update dt unless e.killme

      removeEntity e if e.killme

  draw: ->
    e.draw() for id, e of entities

  export: ->
    for id, e of entities
      d = e.export()
      d.id = id
      d.type = e.type
      d

