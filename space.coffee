class SpaceGame extends atom.Game
  constructor: ->
    super()
    @bind()
    @entities = []
    @deadEntityIDs = []

    @space = new cp.Space

    @frontFB = makeFB atom.width, atom.height
    gl.clearColor 0, 0, 0, 1
    gl.clear gl.COLOR_BUFFER_BIT
    @backFB = makeFB atom.width, atom.height
    gl.clearColor 0, 0, 0, 1
    gl.clear gl.COLOR_BUFFER_BIT
    gl.bindFramebuffer gl.FRAMEBUFFER, null
    gl.enable gl.BLEND
    gl.blendFunc gl.SRC_ALPHA, gl.ONE

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

    atom.input.bind atom.key.E, 'explode'

  _removeDeadEntities: ->
    if @deadEntityIDs.length > 0
      # remove dead entities
      @deadEntityIDs.sort (a, b) -> b - a
      for id in @deadEntityIDs
        @entities[id].onDestroy?()
        @entities.splice id, 1
      @deadEntityIDs = []

  update: (dt) ->
    dt = 1 / 30
    @space.step dt
    e?.update? dt for e in @entities
    @_removeDeadEntities()
    @screen = {
      x:-atom.width/2, y:-atom.height/2,
      w:atom.width, h:atom.height
    }
  draw: ->
    # clear new
    # draw old to new in offset pos
    # darken new
    # draw frame to new
    # draw new to screen
    gl.bindFramebuffer gl.FRAMEBUFFER, @frontFB
    gl.clearColor 0, 0, 0, 1
    gl.clear gl.COLOR_BUFFER_BIT
    if @last_draw_centre
      dx = @last_draw_centre.x - player.body.p.x
      dy = @last_draw_centre.y - player.body.p.y
      drawTex @backFB.tex, dx, dy, atom.width, atom.height, 0.8
    # TODO: darken
    w = 2 / atom.canvas.width
    h = -2 / atom.canvas.height
    shader.regular.setUniform 'projection', [
      w, 0, 0, 0
      0, h, 0, 0
      0, 0, 1, 1
      0, 0, 0, 1
    ]
    shader.gradient.setUniform 'projection', [
      w, 0, 0, 0
      0, h, 0, 0
      0, 0, 1, 1
      0, 0, 0, 1
    ]
    @worldMatrix = new MatrixStack
    @worldMatrix.translate -player.body.p.x, -player.body.p.y
    e.draw?() for e in @entities
    gl.bindFramebuffer gl.FRAMEBUFFER, null
    drawTex @frontFB.tex, 0, 0, atom.width, atom.height, 1.0#, shader.fxaa
    @last_draw_centre = { x:player.body.p.x, y:player.body.p.y }
    tmp = @backFB
    @backFB = @frontFB
    @frontFB = tmp

class Entity
  constructor: ->
    game.addEntity this

  destroy: ->
    game.removeEntity this

  update: ->
  draw: ->

clamp = (f, minv, maxv) -> Math.min(Math.max(f, minv), maxv)
updateVelocityFriction = (gravity, damping, dt) ->
  # drag
  b = 0.8
  fdx = -b * @vx
  fdy = -b * @vy
  vx = @vx * damping + (gravity.x + (fdx + @f.x) * @m_inv) * dt
  vy = @vy * damping + (gravity.y + (fdy + @f.y) * @m_inv) * dt

  v_limit = @v_limit
  lensq = vx * vx + vy * vy
  scale = if lensq > v_limit*v_limit then v_limit / Math.sqrt(len) else 1
  @vx = vx * scale
  @vy = vy * scale
  
  w_limit = @w_limit
  @w = clamp(@w*damping + @t*@i_inv*dt, -w_limit, w_limit)
  
  @sanityCheck()

class StaticShapeEntity extends Entity
  constructor: (vs, x, y) ->
    super()
    polys = convexicatePolygon(vs)
    @shapes = []
    for p in polys
      @shapes.push new cp.PolyShape game.space.staticBody, p, new cp.Vect(x,y)
      game.space.addShape @shapes[@shapes.length-1]
  onDestroy: ->
    for s in @shapes
      game.space.removeShape s

class ShapeEntity extends Entity
  constructor: (vs, density = 1) ->
    super()
    area = 1#cp.areaForPoly verts
    mass = area * density
    moment = cp.momentForPoly mass, vs, cp.vzero
    @body = new cp.Body mass, moment
    @body.velocity_func = updateVelocityFriction
    game.space.addBody @body
    @cpshape = new cp.PolyShape @body, vs, cp.vzero
    game.space.addShape @cpshape
  onDestroy: ->
    game.space.removeBody @body
    game.space.removeShape @cpshape

class Ship extends ShapeEntity
  constructor: (x, y) ->
    @shape = @makeShape()
    super @shape.vertices
    @body.setPos new cp.Vect x, y
    @engine = @makeEngine()
    @turnSpeed = 0.2

  makeShape: ->
    n = 4
    new StaticShape [
      [-10,-10, 1,0,0,1]
      [-10,10,  1,0,0,1]
      [n,10,  1,0,0,1]
      [10,n, 1,0,0,1]
      [10,-n, 1,0,0,1]
      [n,-10, 1,0,0,1]
      [-10,-10, 1,0,0,1]
    ]
  makeEngine: ->
    g = new Gradient [
      [0, 'rgba(0,0,0,0)']
      [0.15, 'rgba(90,105,190,0.2)']
      [0.2, 'rgba(90,105,190,1)']
      [0.4, 'rgba(80,30,190,0.4)']
      [1, 'rgba(10,0,40,0.0)']
    ]
    g.is_on = no
    g.on = ->
      @base = game.time unless @is_on
      @is_on = yes
    g.off = ->
      @is_on = no
    g._draw = g.draw
    g.draw = (x, y) ->
      return unless @is_on
      size = Math.tan((game.time - @base)*4) * 30
      size = 0 if size < 0 or size > 160
      game.worldMatrix.push()
      game.worldMatrix.translate x, y
      @_draw size/3, size
      game.worldMatrix.pop()
    g

  update: (dt) ->
    if @targetAngle
      a = turnTo @body.a, @targetAngle, @turnSpeed
      @body.w = (a - @body.a) / dt
    else
      @body.w = 0
    @engine.ddt += Math.random()*0.1
    @engine.ddt = Math.max -0.3, Math.min 0.3, @engine.ddt
    @body.resetForces()
    if @fx or @fy
      @engine.on()
      @body.applyForce new cp.Vect(@fx, @fy), cp.vzero
    else
      @engine.off()
    @fx = @fy = 0
    super(dt)
  draw: ->
    game.worldMatrix.push()
    game.worldMatrix.translate @body.p.x, @body.p.y
    game.worldMatrix.rotate @body.a
    @shape.draw()
    @engine.draw -13, 0
    game.worldMatrix.pop()
  thrust: (fx, fy) ->
    @fx += fx
    @fy += fy

class PlayerShip extends Ship
  constructor: (x, y) ->
    super x, y
    @turnSpeed = 0.1
    @shotTime = 0
  update: (dt) ->
    dx = atom.input.mouse.x - atom.width/2
    dy = atom.input.mouse.y - atom.height/2
    @targetAngle = Math.atan2(dy, dx)
    s = 100
    if atom.input.down 'forward'
      @thrust Math.cos(@body.a) * s, Math.sin(@body.a) * s
    ts = s * 0.7
    if atom.input.down 'back'
      @thrust Math.cos(@body.a + TAU/2) * ts, Math.sin(@body.a + TAU/2) * ts
    if atom.input.down 'right'
      @thrust Math.cos(@body.a + TAU/4) * ts, Math.sin(@body.a + TAU/4) * ts
    if atom.input.down 'left'
      @thrust Math.cos(@body.a - TAU/4) * ts, Math.sin(@body.a - TAU/4) * ts

    if @shotTime > 0
      @shotTime -= dt
    if atom.input.down 'shoot'
      if @shotTime <= 0
        @shoot x:@body.p.x+dx, y: @body.p.y+dy
        @shotTime = Math.random() * 0.1
    super(dt)
  shoot: (target) ->
    new Bullet this, @body.p.x, @body.p.y, target

class EnemyShip extends Ship
  constructor: (x, y) ->
    super x, y
    @turnSpeed = 0.04
  update: (dt) ->
    dx = player.x - @x
    dy = player.y - @y
    @targetAngle = Math.atan2(dy, dx) - TAU/4
    @vx += -Math.sin(@body.a) * dt * 50
    @vy += Math.cos(@body.a) * dt * 50
    super(dt)

class Box extends Entity
  constructor: (x,y) ->
    super x, y
    vertices = [-5,-5, -5,5, 5,5, 5,-5]
    colors = [0,1,0,1, 0,1,0,1, 0,1,0,1, 0,1,0,1]
    @shape = new StaticShape [
      [-5,-5, 0,1,0,1]
      [-5, 5, 0,1,0,1]
      [ 5, 5, 0,1,0,1]
      [ 5,-5, 0,1,0,1]
      [-5,-5, 0,1,0,1]
    ]

  update: (dt) ->
    r = -> Math.random()*2-1
    if atom.input.down 'explode'
      if Math.random() < 0.08
        new Explosion @x+r()*50, @y+r()*50

  draw: ->
    game.worldMatrix.push()
    game.worldMatrix.translate @x, @y
    game.worldMatrix.rotate @angle
    @shape.draw()
    game.worldMatrix.pop()

class Explosion extends Entity
  constructor: (@x, @y) ->
    super()
    @gradient = new Gradient [
      [0, 'rgba(190,105,90,1)']
      [0.25, 'rgba(5,30,80,0.4)']
      [1, 'rgba(10,0,40,0)']
    ]
    @time = Math.random()*0.01
  update: (dt) ->
    @time += dt
    if @time > 0.5
      @destroy()
  draw: ->
    d = Math.min 0.5, @time
    fac = 0.48 * 4 * Math.PI
    size = 15 * (1 + Math.tan(d * fac))
    game.worldMatrix.push()
    game.worldMatrix.translate @x, @y
    @gradient.draw size
    game.worldMatrix.pop()
  destroy: ->
    @gradient.destroy()
    super()

class Shockwave extends Entity
  constructor: (@x, @y, @angle) ->
    @orig_x = @x
    @orig_y = @y
    super()
    @gradient = new Gradient [
      [0, 'rgba(212,103,113,0.025)']
      [0.6, 'rgba(212,103,113,0.035)']
      [0.8, 'rgba(212,103,113,0.075)']
      [1.0, 'rgba(212,103,113,0.0)']
    ]
    @size = 30
  destroy: ->
    @gradient.destroy()
    new Explosion @orig_x, @orig_y
    super()
  update: (dt) ->
    @size += dt * 60
    if @size > 50
      @destroy()
    c = Math.cos @angle
    s = Math.sin @angle
    @x += c*30*dt
    @y += s*30*dt
  draw: ->
    size = @size
    game.worldMatrix.push()
    game.worldMatrix.translate @x, @y
    game.worldMatrix.rotate @angle+TAU/4
    @gradient.draw size, size/4
    game.worldMatrix.pop()

class Bullet extends Entity
  constructor: (@source, @x, @y, @target) ->
    super()
    @angle = Math.atan2 @target.y-y, @target.x-x
    @angle += TAU/4 * if Math.random() < 0.5 then -1 else 1
    @turnSpeed = 0.15 + Math.random() * 0.15
    @shape = new StaticShape [
      [-0.5,0, 1,0.57,0,1]
      [0.5,0, 1,0.57,0,1]
    ]
    @shape.lineWidth = 1
    @life = 4
  update: (dt) ->
    dx = @target.x - @x
    dy = @target.y - @y
    targetAngle = Math.atan2 dy, dx
    @angle = turnTo @angle, targetAngle, @turnSpeed
    dist = Math.sqrt dx*dx+dy*dy
    @life -= dt
    if dist < 200*dt or @life < 0
      @explode()
    else
      c = Math.cos @angle
      s = Math.sin @angle
      dx = c*200*dt
      dy = s*200*dt
      d = game.space.segmentQueryFirst cp.v(@x, @y), cp.v(@x+dx,@y+dy), ~0, 0
      if d.shape and d.shape != @source.shape
        @x += dx*d.t
        @y += dy*d.t
        @explode()
      else
        @x += dx
        @y += dy

  destroy: ->
    @shape.destroy()
    super()
  explode: ->
    @destroy()
    new Shockwave @x, @y, @angle

  draw: ->
    game.worldMatrix.push()
    game.worldMatrix.translate @x, @y
    game.worldMatrix.rotate @angle
    game.worldMatrix.scale 10, 10
    @shape.draw()
    game.worldMatrix.pop()

class Asteroid extends StaticShapeEntity
  constructor: (@x, @y) ->
    @shape = new StaticShape @generate_verts()
    super(@shape.vertices, @x, @y)
  generate_verts: ->
    verts = []
    num = 10
    size = 20+60*Math.random()
    for i in [0..num-1]
      phi = -TAU/num*i
      r = size + (Math.random()*2-1) * size/4
      x = r * Math.cos phi
      y = r * Math.sin phi
      verts.push [x, y, 0.5, 0.5, 0.5, 0.4]
    verts.push verts[0]
    verts
  draw: ->
    game.worldMatrix.push()
    game.worldMatrix.translate @x, @y
    @shape.draw()
    game.worldMatrix.pop()

window.game = game = new SpaceGame

for i in [0..1000]
  new Asteroid 10000*(2*Math.random()-1), 10000*(2*Math.random()-1)

player = new PlayerShip 0, 0
#new Box 0, 0
#new EnemyShip 100,0

window.onblur = -> game.stop()
window.onfocus = -> game.run()

game.run()
