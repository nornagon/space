TAU = Math.PI*2

gl = atom.gl

nextPOT = (n) ->
  pot = 1
  while pot < n
    pot <<= 1
  pot
makeFB = (w, h) ->
  texW = nextPOT w
  texH = nextPOT h
  fb = gl.createFramebuffer()
  gl.bindFramebuffer gl.FRAMEBUFFER, fb
  fb.tex = gl.createTexture()
  fb.tex.maxS = w / texW
  fb.tex.maxT = h / texH
  fb.tex.width = w
  fb.tex.height = h
  gl.bindTexture gl.TEXTURE_2D, fb.tex
  gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR
  gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR
  gl.texImage2D gl.TEXTURE_2D, 0, gl.RGBA, texW, texH, 0, gl.RGBA, gl.UNSIGNED_BYTE, null
  gl.framebufferTexture2D gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, fb.tex, 0
  return fb

_drawTexVerts = gl.createBuffer()
_drawTexTexCoords = gl.createBuffer()
drawTex = (tex, x, y, w, h, multiplier = 1.0) ->
  shader.tex.setUniform 'tex', 0
  shader.tex.setUniform 'mult', multiplier
  gl.bindTexture gl.TEXTURE_2D, tex
  gl.activeTexture gl.TEXTURE0
  vs = [-1+2*x/atom.width,     1-2*y/atom.height     # tl
        -1+2*x/atom.width,     1-2*(y+h)/atom.height # bl
        -1+2*(x+w)/atom.width, 1-2*y/atom.height     # tr
        -1+2*(x+w)/atom.width, 1-2*(y+h)/atom.height]# br
  tcs = [0,tex.maxT, 0,0, tex.maxS,tex.maxT, tex.maxS,0]
  gl.bindBuffer gl.ARRAY_BUFFER, _drawTexVerts
  gl.bufferData gl.ARRAY_BUFFER, new Float32Array(vs), gl.STATIC_DRAW
  gl.vertexAttribPointer shader.tex.attribute.vertexPosition.location, 2, gl.FLOAT, false, 0, 0
  gl.bindBuffer gl.ARRAY_BUFFER, _drawTexTexCoords
  gl.bufferData gl.ARRAY_BUFFER, new Float32Array(tcs), gl.STATIC_DRAW
  gl.vertexAttribPointer shader.tex.attribute.vertexTexCoord.location, 2, gl.FLOAT, false, 0, 0
  gl.drawArrays gl.TRIANGLE_STRIP, 0, 4

_drawRectVertexBuf = gl.createBuffer()
_drawRectColorBuf = gl.createBuffer()
drawRect = (r, g, b, a) ->
  vertexBuf = _drawRectVertexBuf
  colorBuf = _drawRectColorBuf

  shader.regular.use()

  vertices = [0,0, 0,atom.height, atom.width,0, atom.width,atom.height]
  gl.bindBuffer gl.ARRAY_BUFFER, vertexBuf
  gl.bufferData gl.ARRAY_BUFFER, new Float32Array(vertices), gl.STATIC_DRAW
  gl.vertexAttribPointer shader.regular.attribute.vertexPosition.location, 2, gl.FLOAT, false, 0, 0

  colors = new Array(16)
  for i in [0...4]
    colors[i*4+0] = r
    colors[i*4+1] = g
    colors[i*4+2] = b
    colors[i*4+3] = a
  gl.bindBuffer gl.ARRAY_BUFFER, colorBuf
  gl.bufferData gl.ARRAY_BUFFER, new Float32Array(colors), gl.STATIC_DRAW
  gl.vertexAttribPointer shader.regular.attribute.vertexColor.location, 4, gl.FLOAT, false, 0, 0
  shader.regular.setUniform 'world', [
    1, 0, 0
    0, 1, 0
    0, 0, 1
  ]
  gl.drawArrays gl.TRIANGLE_STRIP, 0, 4

class MatrixStack
  constructor: ->
    @matrix = [1,0,0, 0,1,0, 0,0,1]
    @stack = []
  push: ->
    @stack.push @matrix
  pop: ->
    return unless @stack.length > 0
    @matrix = @stack.pop()
  mult: (b) ->
    a = @matrix
    @matrix = new Array(9)
    for r in [0...3]
      for c in [0...3]
        @matrix[3*r+c] = b[3*r+0]*a[0+c] +
                         b[3*r+1]*a[3+c] +
                         b[3*r+2]*a[6+c]
    return
  translate: (x, y) ->
    @mult [
      1,0,0
      0,1,0
      x,y,1
    ]
  rotate: (phi) ->
    c = Math.cos phi
    s = Math.sin phi
    @mult [
      c,s,0
     -s,c,0
      0,0,1
    ]
  scale: (sx, sy) ->
    @mult [
      sx,0,0
      0,sy,0
      0,0,1
    ]

class Gradient
  shader.gradient.use()
  shader.gradient.setUniform 'gradientTex', 0
  vertexBuf = gl.createBuffer()
  gl.bindBuffer gl.ARRAY_BUFFER, vertexBuf
  gl.bufferData gl.ARRAY_BUFFER, new Float32Array([0,0, 0,1, 1,0, 1,1]), gl.STATIC_DRAW
  gl.vertexAttribPointer shader.gradient.attribute.vertexPosition.location, 2, gl.FLOAT, false, 0, 0

  mat = new MatrixStack

  constructor: (stops, size=256) ->
    canvas = document.createElement 'canvas'
    canvas.style.position = 'absolute'
    canvas.width = nextPOT size
    canvas.height = 1
    ctx = canvas.getContext '2d'
    g = ctx.createLinearGradient 0, 0, size, 0
    for s in stops
      g.addColorStop s[0], s[1]
    ctx.fillStyle = g
    ctx.fillRect 0,0,canvas.width,1
    data = ctx.getImageData 0, 0, canvas.width, 1
    @tex = gl.createTexture()
    gl.bindTexture gl.TEXTURE_2D, @tex
    gl.texImage2D gl.TEXTURE_2D, 0, gl.RGBA, gl.RGBA, gl.UNSIGNED_BYTE, data
    gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR
    gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR
    gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE
    gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE
    @length = size / canvas.width
  draw: (x, y, size) ->
    mat.push()
    mat.translate(x-size/2,y-size/2)
    mat.scale(size, size)
    shader.gradient.setUniform 'world', mat.matrix
    mat.pop()
    shader.gradient.setUniform 'length', @length
    gl.activeTexture 0
    gl.bindTexture gl.TEXTURE_2D, @tex
    gl.bindBuffer gl.ARRAY_BUFFER, vertexBuf
    gl.vertexAttribPointer shader.gradient.attribute.vertexPosition.location, 2, gl.FLOAT, false, 0, 0
    gl.drawArrays gl.TRIANGLE_STRIP, 0, 4
  destroy: ->
    gl.deleteTexture @tex

class SpaceGame extends atom.Game
  constructor: ->
    super()
    @bind()
    @entities = []
    @deadEntityIDs = []

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

  update: (dt) ->
    e?.update? dt for e in @entities
    if @deadEntityIDs.length > 0
      # remove dead entities
      @deadEntityIDs.sort (a, b) -> b - a
      for id in @deadEntityIDs
        @entities.splice id, 1
      @deadEntityIDs = []
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
      dx = @last_draw_centre.x - player.x
      dy = @last_draw_centre.y - player.y
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
    @worldMatrix.translate -player.x, -player.y
    e.draw?() for e in @entities
    gl.bindFramebuffer gl.FRAMEBUFFER, null
    drawTex @frontFB.tex, 0, 0, atom.width, atom.height, 1.0
    @last_draw_centre = { x:player.x, y:player.y }
    tmp = @backFB
    @backFB = @frontFB
    @frontFB = tmp

class StaticShape
  constructor: (verts) ->
    vertices = []
    colors = []
    for v in verts
      vertices = vertices.concat v[0..1]
      colors = colors.concat v[2..5]
    @numElements = vertices.length / 2
    @vertexBuf = gl.createBuffer()
    gl.bindBuffer gl.ARRAY_BUFFER, @vertexBuf
    gl.bufferData gl.ARRAY_BUFFER, new Float32Array(vertices), gl.STATIC_DRAW
    @colorBuf = gl.createBuffer()
    gl.bindBuffer gl.ARRAY_BUFFER, @colorBuf
    gl.bufferData gl.ARRAY_BUFFER, new Float32Array(colors), gl.STATIC_DRAW
    @lineWidth = 2

  draw: ->
    shader.regular.use()
    gl.bindBuffer gl.ARRAY_BUFFER, @vertexBuf
    gl.vertexAttribPointer shader.regular.attribute.vertexPosition.location, 2, gl.FLOAT, false, 0, 0
    gl.bindBuffer gl.ARRAY_BUFFER, @colorBuf
    gl.vertexAttribPointer shader.regular.attribute.vertexColor.location, 4, gl.FLOAT, false, 0, 0
    gl.lineWidth @lineWidth
    gl.drawArrays gl.LINE_STRIP, 0, @numElements

class Entity
  constructor: (@x, @y) ->
    game.addEntity this
    @vx = @vy = 0
    @angle = 0

  destroy: ->
    game.removeEntity this

  update: (dt) ->
    @x += @vx * dt
    @y += @vy * dt
    @vx *= 0.95
    @vy *= 0.95

class Ship extends Entity
  constructor: (x, y) ->
    super(x, y)
    @shape = new StaticShape [
      [-10,0, 1,0,0,1]
      [10,0,  1,0,0,1]
      [0,20,  1,0,0,1]
      [-10,0, 1,0,0,1]
    ]
    @turnSpeed = 0.2

  update: (dt) ->
    if @targetAngle
      diff = @targetAngle - @angle
      diff -= TAU while diff > TAU/2
      diff += TAU while diff < -TAU/2
      if diff > 0
        # turn ccw
        if diff < @turnSpeed
          @angle = @targetAngle
        else
          @angle += @turnSpeed
      else
        # turn cw
        if -diff < @turnSpeed
          @angle = @targetAngle
        else
          @angle -= @turnSpeed
    super(dt)
  draw: ->
    game.worldMatrix.push()
    game.worldMatrix.translate @x, @y
    game.worldMatrix.rotate @angle
    shader.regular.setUniform 'world', game.worldMatrix.matrix
    game.worldMatrix.pop()
    @shape.draw()

class PlayerShip extends Ship
  constructor: (x, y) ->
    super x, y
    @turnSpeed = 0.1
    @shotTime = 0
  update: (dt) ->
    dx = atom.input.mouse.x - atom.width/2
    dy = atom.input.mouse.y - atom.height/2
    @targetAngle = Math.atan2(dy, dx) - TAU/4
    if atom.input.down 'forward'
      @vx += -Math.sin(@angle) * dt * 500
      @vy += Math.cos(@angle) * dt * 500

    if @shotTime > 0
      @shotTime -= dt
    if atom.input.down 'shoot'
      if @shotTime <= 0
        @shoot x:@x+dx, y: @y+dy
        @shotTime = 0.3
    super(dt)
  shoot: (target) ->
    new Bullet @x, @y, target

class EnemyShip extends Ship
  constructor: (x, y) ->
    super x, y
    @turnSpeed = 0.04
  update: (dt) ->
    dx = player.x - @x
    dy = player.y - @y
    @targetAngle = Math.atan2(dy, dx) - TAU/4
    @vx += -Math.sin(@angle) * dt * 300
    @vy += Math.cos(@angle) * dt * 300
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
    shader.regular.setUniform 'world', game.worldMatrix.matrix
    game.worldMatrix.pop()
    @shape.draw()

class Explosion extends Entity
  constructor: (x, y) ->
    super x, y
    @gradient = new Gradient [
      [0, 'rgba(190,105,90,1)']
      [0.25, 'rgba(5,30,80,0.4)']
      [1, 'rgba(10,0,40,0)']
    ]
    @time = 0
  update: (dt) ->
    @time += dt
    if @time > 0.5
      @destroy()
  draw: ->
    d = Math.min 0.5, @time
    fac = 0.48 * 4 * Math.PI
    size = 15 * (1 + Math.tan(d * fac))
    @gradient.draw @x-player.x, @y-player.y, size
  destroy: ->
    @gradient.destroy()
    super()

class Bullet extends Entity
  constructor: (x, y, @target) ->
    super x, y
    @angle = Math.atan2 @target.y-y, @target.x-x
    @shape = new StaticShape [
      [0,0, 1,0.57,0,1]
      [1,0, 1,0.57,0,1]
    ]
  update: (dt) ->
    dx = @target.x - @x
    dy = @target.y - @y
    dist = Math.sqrt dx*dx+dy*dy
    if dist < 100*dt
      @destroy()
      new Explosion @x, @y
    else
      @vx = dx/dist*100
      @vy = dy/dist*100
    super dt
  draw: ->
    game.worldMatrix.push()
    game.worldMatrix.translate @x, @y
    game.worldMatrix.rotate @angle
    game.worldMatrix.scale 5, 5
    shader.regular.setUniform 'world', game.worldMatrix.matrix
    game.worldMatrix.pop()
    @shape.draw()

window.game = game = new SpaceGame

player = new PlayerShip 0, 0
new Box 0, 0
new EnemyShip 100,0

window.onblur = -> game.stop()
window.onfocus = -> game.run()

game.run()
