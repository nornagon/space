TAU = Math.PI*2

gl = atom.gl

vertexShaderSource = '''
attribute vec2 vertexPosition;
attribute vec4 vertexColor;
varying vec4 varColor;

uniform mat3 world;
uniform mat4 projection;

void main(void) {
  vec3 position = world * vec3(vertexPosition.x, vertexPosition.y, 1.0);
  gl_Position = projection * vec4(position.x, position.y, 0.0, 1.0);
  varColor = vertexColor;
}
'''

fragmentShaderSource = '''
#ifdef GL_ES
precision highp float;
#endif

varying vec4 varColor;

void main() {
  gl_FragColor = varColor;
}
'''

texVertexSource = '''
attribute vec2 vertexPosition;
attribute vec2 vertexTexCoord;

varying vec2 texCoord;

void main(void) {
  gl_Position = vec4(vertexPosition, 0, 1);
  texCoord = vertexTexCoord;
}
'''
texFragmentSource = '''
#ifdef GL_ES
precision highp float;
#endif
uniform sampler2D tex;

varying vec2 texCoord;

void main(void) {
  vec4 col = texture2D(tex, texCoord);
  gl_FragColor = vec4(col.rgb, 0.8);
}
'''

class Shader
  constructor: (vsSource, fsSource) ->
    @vs = gl.createShader gl.VERTEX_SHADER
    gl.shaderSource @vs, vsSource
    gl.compileShader @vs

    unless gl.getShaderParameter @vs, gl.COMPILE_STATUS
      throw 'vertex shader error: ' + gl.getShaderInfoLog @vs

    @fs = gl.createShader gl.FRAGMENT_SHADER
    gl.shaderSource @fs, fsSource
    gl.compileShader @fs

    unless gl.getShaderParameter @fs, gl.COMPILE_STATUS
      throw 'fragment shader error: ' + gl.getShaderInfoLog @fs

    @program = gl.createProgram()
    gl.attachShader @program, @vs
    gl.attachShader @program, @fs
    gl.linkProgram @program

    unless gl.getProgramParameter @program, gl.LINK_STATUS
      throw 'link error: ' + gl.getProgramInfoLog @program

    gl.useProgram @program

    re = /^(attribute|uniform)\s+(\S+?)\s+(\S+?);$/gm
    @attribute = {}
    @uniform = {}
    for src in [vsSource, fsSource]
      while m = re.exec src
        switch m[1]
          when 'attribute'
            @attribute[m[3]] =
              location: location = gl.getAttribLocation @program, m[3]
              type: m[2]
            gl.enableVertexAttribArray location
          when 'uniform'
            @uniform[m[3]] =
              location: gl.getUniformLocation @program, m[3]
              type: m[2]
  use: ->
    gl.useProgram @program
  setUniform: (name, val) ->
    throw 'no such uniform' unless u = @uniform[name]
    @use()
    switch u.type
      when 'mat3'
        gl.uniformMatrix3fv u.location, false, new Float32Array(val)
      when 'mat4'
        gl.uniformMatrix4fv u.location, false, new Float32Array(val)
      when 'sampler2D'
        gl.uniform1i u.location, val
      else
        throw "don't know how to set #{u.type}"

shader = {
  regular: new Shader vertexShaderSource, fragmentShaderSource
  tex: new Shader texVertexSource, texFragmentSource
}

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
drawTex = (tex, x, y, w, h) ->
  shader.tex.setUniform 'tex', 0
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

  update: (dt) ->
    e?.update? dt for e in @entities
    if @deadEntityIDs.length > 0
      # remove dead entities
      @deadEntityIDs.sort_by (a, b) -> b - a
      for id in @deadEntityIDs
        @entities.splice id, 1
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
      drawTex @backFB.tex, dx, dy, atom.width, atom.height
    # TODO: darken
    w = 2 / atom.canvas.width
    h = -2 / atom.canvas.height
    shader.regular.setUniform 'projection', [
      w, 0, 0, 0
      0, h, 0, 0
      0, 0, 1, 1
      0, 0, 0, 1
    ]
    @worldMatrix = new MatrixStack
    @worldMatrix.translate -player.x, -player.y
    e.draw?() for e in @entities
    gl.bindFramebuffer gl.FRAMEBUFFER, null
    drawTex @frontFB.tex, 0, 0, atom.width, atom.height
    @last_draw_centre = { x:player.x, y:player.y }
    tmp = @backFB
    @backFB = @frontFB
    @frontFB = tmp

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
    @vx *= 0.95
    @vy *= 0.95

class Ship extends PhysicalEntity
  constructor: (x, y) ->
    super(x, y)
    vertices = [-10,0, 10,0, 0,20, -10,0]
    @vertexBuf = gl.createBuffer()
    gl.bindBuffer gl.ARRAY_BUFFER, @vertexBuf
    gl.bufferData gl.ARRAY_BUFFER, new Float32Array(vertices), gl.STATIC_DRAW
    colors = [1,0,0,1, 1,0,0,1, 1,0,0,1, 1,0,0,1]
    @colorBuf = gl.createBuffer()
    gl.bindBuffer gl.ARRAY_BUFFER, @colorBuf
    gl.bufferData gl.ARRAY_BUFFER, new Float32Array(colors), gl.STATIC_DRAW
  draw: ->
    shader.regular.use()
    gl.bindBuffer gl.ARRAY_BUFFER, @vertexBuf
    gl.vertexAttribPointer shader.regular.attribute.vertexPosition.location, 2, gl.FLOAT, false, 0, 0
    gl.bindBuffer gl.ARRAY_BUFFER, @colorBuf
    gl.vertexAttribPointer shader.regular.attribute.vertexColor.location, 4, gl.FLOAT, false, 0, 0
    game.worldMatrix.push()
    game.worldMatrix.translate @x, @y
    game.worldMatrix.rotate @angle
    shader.regular.setUniform 'world', game.worldMatrix.matrix
    game.worldMatrix.pop()
    gl.lineWidth 2
    gl.drawArrays gl.LINE_STRIP, 0, 4

class PlayerShip extends Ship
  constructor: (x, y) ->
    super x, y
  update: (dt) ->
    dx = atom.input.mouse.x - atom.width/2
    dy = atom.input.mouse.y - atom.height/2
    @angle = Math.atan2(dy, dx) - TAU/4
    if atom.input.down 'forward'
      @vx += -Math.sin(@angle) * dt * 0.001
      @vy += Math.cos(@angle) * dt * 0.001
    super(dt)

class Box extends PhysicalEntity
  constructor: (x,y) ->
    super x, y
    vertices = [-5,-5, -5,5, 5,5, 5,-5]
    @vertexBuf = gl.createBuffer()
    gl.bindBuffer gl.ARRAY_BUFFER, @vertexBuf
    gl.bufferData gl.ARRAY_BUFFER, new Float32Array(vertices), gl.STATIC_DRAW
    colors = [0,1,0,1, 0,1,0,1, 0,1,0,1, 0,1,0,1]
    @colorBuf = gl.createBuffer()
    gl.bindBuffer gl.ARRAY_BUFFER, @colorBuf
    gl.bufferData gl.ARRAY_BUFFER, new Float32Array(colors), gl.STATIC_DRAW
  draw: ->
    shader.regular.use()
    gl.bindBuffer gl.ARRAY_BUFFER, @vertexBuf
    gl.vertexAttribPointer shader.regular.attribute.vertexPosition.location, 2, gl.FLOAT, false, 0, 0
    gl.bindBuffer gl.ARRAY_BUFFER, @colorBuf
    gl.vertexAttribPointer shader.regular.attribute.vertexColor.location, 4, gl.FLOAT, false, 0, 0
    game.worldMatrix.push()
    game.worldMatrix.translate @x, @y
    game.worldMatrix.rotate @angle
    shader.regular.setUniform 'world', game.worldMatrix.matrix
    game.worldMatrix.pop()
    gl.lineWidth 2
    gl.drawArrays gl.LINE_LOOP, 0, 4

window.game = game = new SpaceGame

player = new PlayerShip atom.canvas.width / 2, atom.canvas.height / 2
new Box atom.canvas.width / 2, atom.canvas.height / 2

#new Test

window.onblur = game.stop()
window.onfocus = game.run()

game.run()
