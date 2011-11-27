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
  gl.bindTexture gl.TEXTURE_2D, fb.tex
  gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR
  gl.texParameteri gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR
  gl.texImage2D gl.TEXTURE_2D, 0, gl.RGBA, texW, texH, 0, gl.RGBA, gl.UNSIGNED_BYTE, null
  gl.framebufferTexture2D gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, fb.tex, 0
  return fb

_drawTexVerts = gl.createBuffer()
_drawTexTexCoords = gl.createBuffer()
exports.drawTex = drawTex = (tex, x, y, w, h, multiplier = 1.0) ->
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
