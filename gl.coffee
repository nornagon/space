exports ?= window
exports.gl = gl = atom.gl

exports.makeFB = makeFB = (w, h) ->
  texW = nextPOT w
  texH = nextPOT h
  fb = gl.createFramebuffer()
  gl.bindFramebuffer gl.FRAMEBUFFER, fb
  fb.tex = gl.createTexture()
  fb.tex.maxS = w / texW
  fb.tex.maxT = h / texH
  fb.tex.width = w
  fb.tex.height = h
  fb.tex.texW = texW
  fb.tex.texH = texH
  gl.bindTexture gl.TEXTURE_2D, fb.tex
  gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR
  gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR
  gl.texImage2D gl.TEXTURE_2D, 0, gl.RGBA, texW, texH, 0, gl.RGBA, gl.UNSIGNED_BYTE, null
  gl.framebufferTexture2D gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, fb.tex, 0
  return fb

_drawTexVerts = gl.createBuffer()
_drawTexTexCoords = gl.createBuffer()
exports.drawTex = drawTex = (tex, x, y, w, h, multiplier = 1.0, prog = shader.tex) ->
  prog.setUniform 'tex', 0
  if prog == shader.fxaa
    prog.setUniform 'inverse_buffer_size', 1/tex.texW, 1/tex.texH
  else if prog == shader.tex
    prog.setUniform 'mult', multiplier
  gl.activeTexture gl.TEXTURE0
  gl.bindTexture gl.TEXTURE_2D, tex
  vs = [-1+2*x/atom.width,     1-2*y/atom.height     # tl
        -1+2*x/atom.width,     1-2*(y+h)/atom.height # bl
        -1+2*(x+w)/atom.width, 1-2*y/atom.height     # tr
        -1+2*(x+w)/atom.width, 1-2*(y+h)/atom.height]# br
  tcs = [0,tex.maxT, 0,0, tex.maxS,tex.maxT, tex.maxS,0]
  gl.bindBuffer gl.ARRAY_BUFFER, _drawTexVerts
  gl.bufferData gl.ARRAY_BUFFER, new Float32Array(vs), gl.STATIC_DRAW
  gl.vertexAttribPointer prog.attribute.vertexPosition.location, 2, gl.FLOAT, false, 0, 0
  gl.bindBuffer gl.ARRAY_BUFFER, _drawTexTexCoords
  gl.bufferData gl.ARRAY_BUFFER, new Float32Array(tcs), gl.STATIC_DRAW
  gl.vertexAttribPointer prog.attribute.vertexTexCoord.location, 2, gl.FLOAT, false, 0, 0
  gl.drawArrays gl.TRIANGLE_STRIP, 0, 4

_drawRectVertexBuf = gl.createBuffer()
_drawRectColorBuf = gl.createBuffer()
exports.drawRect = drawRect = (r, g, b, a) ->
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

exports.Gradient = class Gradient
  shader.gradient.use()
  shader.gradient.setUniform 'gradientTex', 0
  vertexBuf = gl.createBuffer()
  gl.bindBuffer gl.ARRAY_BUFFER, vertexBuf
  gl.bufferData gl.ARRAY_BUFFER, new Float32Array([-1,-1, -1,1, 1,-1, 1,1]), gl.STATIC_DRAW
  gl.vertexAttribPointer shader.gradient.attribute.vertexPosition.location, 2, gl.FLOAT, false, 0, 0

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
  draw: (width, height=width) ->
    mat = game.worldMatrix
    mat.push()
    mat.scale(width/2, height/2)
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

exports.StaticShape = class StaticShape
  constructor: (verts) ->
    vertices = []
    colors = []
    @bb = {x:verts[0][0],y:verts[0][1],w:0,h:0}
    for v in verts
      vertices = vertices.concat v[0..1]
      colors = colors.concat v[2..5]
      @bb = Rect.union @bb, {x:v[0], y:v[1], w:0,h:0}
    @vertices = vertices
    @colors = colors
    @numElements = vertices.length / 2
    @vertexBuf = gl.createBuffer()
    gl.bindBuffer gl.ARRAY_BUFFER, @vertexBuf
    gl.bufferData gl.ARRAY_BUFFER, new Float32Array(vertices), gl.STATIC_DRAW
    @colorBuf = gl.createBuffer()
    gl.bindBuffer gl.ARRAY_BUFFER, @colorBuf
    gl.bufferData gl.ARRAY_BUFFER, new Float32Array(colors), gl.STATIC_DRAW
    @lineWidth = 2

  draw: ->
    unless Rect.intersects game.screen, game.worldMatrix.transformAABB @bb
      return
    shader.regular.setUniform 'world', game.worldMatrix.matrix
    gl.bindBuffer gl.ARRAY_BUFFER, @vertexBuf
    gl.vertexAttribPointer shader.regular.attribute.vertexPosition.location, 2, gl.FLOAT, false, 0, 0
    gl.bindBuffer gl.ARRAY_BUFFER, @colorBuf
    gl.vertexAttribPointer shader.regular.attribute.vertexColor.location, 4, gl.FLOAT, false, 0, 0
    gl.lineWidth @lineWidth
    gl.drawArrays gl.LINE_STRIP, 0, @numElements
  destroy: ->
    gl.deleteBuffer @vertexBuf
    gl.deleteBuffer @colorBuf

