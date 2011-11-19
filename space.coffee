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
  gl_FragColor = vec4(1.0,0.0,0.0,1.0);
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
    @vertexPosition = gl.getAttribLocation @program, 'vertexPosition'
    gl.enableVertexAttribArray @vertexPosition
    @vertexColor = gl.getAttribLocation @program, 'vertexColor'
    gl.enableVertexAttribArray @vertexColor
    @world = gl.getUniformLocation @program, 'world'
    @projection = gl.getUniformLocation @program, 'projection'
  use: ->
    gl.useProgram @program
  setWorld: (m) ->
    @use()
    gl.uniformMatrix3fv @world, false, new Float32Array(m)
  setProjection: (m) ->
    @use()
    gl.uniformMatrix4fv @projection, false, new Float32Array(m)

shader = {
  regular: new Shader vertexShaderSource, fragmentShaderSource
}

class SpaceGame extends atom.Game
  constructor: ->
    super()
    @bind()
    @entities = []
    @deadEntityIDs = []

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
    gl.clearColor 0, 0, 0, 1
    gl.clear gl.COLOR_BUFFER_BIT
    w = 2 / atom.canvas.width
    h = -2 / atom.canvas.height
    shader.regular.setProjection [
      w, 0, 0, 0
      0, h, 0, 0
      0, 0, 1, 1
      -1, 1, 0, 1
    ]
    shader.regular.setWorld [
      1, 0, 0
      0, 1, 0
      0, 0, 1
    ]
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
    vertices = [-5,0, 5,0, 0,10, -5,0]
    @vertexBuf = gl.createBuffer()
    gl.bindBuffer gl.ARRAY_BUFFER, @vertexBuf
    gl.bufferData gl.ARRAY_BUFFER, new Float32Array(vertices), gl.STATIC_DRAW
    colors = [1,0,0,1, 1,0,0,1, 1,0,0,1, 1,0,0,1]
    @colorBuf = gl.createBuffer()
    gl.bindBuffer gl.ARRAY_BUFFER, @colorBuf
    gl.bufferData gl.ARRAY_BUFFER, new Float32Array(colors), gl.STATIC_DRAW
  draw: ->
    gl.bindBuffer gl.ARRAY_BUFFER, @vertexBuf
    gl.vertexAttribPointer shader.regular.vertexPosition, 2, gl.FLOAT, false, 0, 0
    gl.bindBuffer gl.ARRAY_BUFFER, @colorBuf
    gl.vertexAttribPointer shader.regular.vertexColor, 4, gl.FLOAT, false, 0, 0
    c = Math.cos @angle
    s = Math.sin -@angle
    shader.regular.setWorld [
      c, -s, 0
      s, c, 0
      @x, @y, 1
    ]
    gl.drawArrays gl.LINE_STRIP, 0, 4

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

window.game = game = new SpaceGame

player = new PlayerShip atom.canvas.width / 2, atom.canvas.height / 2

window.onblur = game.stop()
window.onfocus = game.run()

game.run()
