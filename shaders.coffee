exports ?= window

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
uniform float mult;

varying vec2 texCoord;

void main(void) {
  vec4 col = texture2D(tex, texCoord);
  gl_FragColor = vec4(col.rgb*mult, 1);
}
'''


gradientVertexSource = '''
attribute vec2 vertexPosition;
uniform mat3 world;
uniform mat4 projection;
varying vec2 fragmentPosition;

void main(void) {
  vec3 pos = world * vec3(vertexPosition, 1);
  gl_Position = projection * vec4(pos.xy, 0, 1);
  fragmentPosition = vertexPosition;
}
'''
gradientFragmentSource = '''
#ifdef GL_ES
precision highp float;
#endif

uniform sampler2D gradientTex; // 1xn
uniform float length; // in texture coordinates [0,1]

varying vec2 fragmentPosition;

float distanceFromCentre(vec2 a) {
  float dx = a.x;
  float dy = a.y;
  return sqrt(dx*dx + dy*dy);
}

void main(void) {
  float dist = distanceFromCentre(fragmentPosition);
  gl_FragColor = texture2D(gradientTex, vec2(dist*length,0));
}
'''

fxaaFragmentSource = '''
precision highp float;

uniform float mult; // unused
uniform sampler2D tex;
varying vec2 texCoord;
uniform vec2 inverse_buffer_size;
#define FXAA_REDUCE_MIN   (1.0/128.0)
#define FXAA_REDUCE_MUL   (1.0/8.0)
#define FXAA_SPAN_MAX     8.0

void    main(){
	vec3 rgbNW = texture2D(tex,  (gl_FragCoord.xy + vec2(-1.0,-1.0)) * inverse_buffer_size).xyz;
	vec3 rgbNE = texture2D(tex,  (gl_FragCoord.xy + vec2(1.0,-1.0)) * inverse_buffer_size).xyz;
	vec3 rgbSW = texture2D(tex,  (gl_FragCoord.xy + vec2(-1.0,1.0)) * inverse_buffer_size).xyz;
	vec3 rgbSE = texture2D(tex,  (gl_FragCoord.xy + vec2(1.0,1.0)) * inverse_buffer_size).xyz;
	vec3 rgbM  = texture2D(tex,  gl_FragCoord.xy  * inverse_buffer_size).xyz;
	vec3 luma = vec3(0.299, 0.587, 0.114);
	float lumaNW = dot(rgbNW, luma);
	float lumaNE = dot(rgbNE, luma);
	float lumaSW = dot(rgbSW, luma);
	float lumaSE = dot(rgbSE, luma);
	float lumaM  = dot(rgbM,  luma);
	float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
	float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));
	
	vec2 dir;
	dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
	dir.y =  ((lumaNW + lumaSW) - (lumaNE + lumaSE));
	
	float dirReduce = max(
        (lumaNW + lumaNE + lumaSW + lumaSE) * (0.25 * FXAA_REDUCE_MUL),
        FXAA_REDUCE_MIN);
	
	float rcpDirMin = 1.0/(min(abs(dir.x), abs(dir.y)) + dirReduce);
	dir = min(vec2( FXAA_SPAN_MAX,  FXAA_SPAN_MAX),
	max(vec2(-FXAA_SPAN_MAX, -FXAA_SPAN_MAX),
	dir * rcpDirMin)) * inverse_buffer_size;
	  
	vec3 rgbA = 0.5 * (
        texture2D(tex,   gl_FragCoord.xy  * inverse_buffer_size + dir * (1.0/3.0 - 0.5)).xyz +
        texture2D(tex,   gl_FragCoord.xy  * inverse_buffer_size + dir * (2.0/3.0 - 0.5)).xyz);
	
	vec3 rgbB = rgbA * 0.5 + 0.25 * (
	texture2D(tex,  gl_FragCoord.xy  * inverse_buffer_size + dir *  - 0.5).xyz +
        texture2D(tex,  gl_FragCoord.xy  * inverse_buffer_size + dir * 0.5).xyz);
	float lumaB = dot(rgbB, luma);
	if((lumaB < lumaMin) || (lumaB > lumaMax)) gl_FragColor = vec4(rgbA,1.0);
	    else gl_FragColor = vec4(rgbB,1.0);
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

    re = /^(attribute|uniform)\s+(\S+?)\s+(\S+?);/gm
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
  setUniform: (name, val...) ->
    throw 'no such uniform' unless u = @uniform[name]
    @use()
    switch u.type
      when 'vec2'
        gl.uniform2f u.location, val[0], val[1]
      when 'mat3'
        gl.uniformMatrix3fv u.location, false, new Float32Array(val[0])
      when 'mat4'
        gl.uniformMatrix4fv u.location, false, new Float32Array(val[0])
      when 'sampler2D'
        gl.uniform1i u.location, val[0]
      when 'float'
        gl.uniform1f u.location, val[0]
      else
        throw "don't know how to set #{u.type}"

exports.shader = shader = {
  regular: new Shader vertexShaderSource, fragmentShaderSource
  tex: new Shader texVertexSource, texFragmentSource
  fxaa: new Shader texVertexSource, fxaaFragmentSource
  gradient: new Shader gradientVertexSource, gradientFragmentSource
}
