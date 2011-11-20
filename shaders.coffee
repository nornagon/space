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

window.shader = {
  regular: new Shader vertexShaderSource, fragmentShaderSource
  tex: new Shader texVertexSource, texFragmentSource
}
