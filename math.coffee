exports ?= window
exports.TAU = TAU = Math.PI*2

exports.Rect = Rect =
  union: (r1, r2) ->
    x: x = Math.min r1.x, r2.x
    y: y = Math.min r1.y, r2.y
    w: Math.max(r1.x+(r1.w ? 0), r2.x+(r2.w ? 0)) - x
    h: Math.max(r1.y+(r1.h ? 0), r2.y+(r2.h ? 0)) - y
  intersects: (r1, r2) ->
    not (
      r1.x+r1.w < r2.x or
      r1.y+r1.h < r2.y or
      r1.x > r2.x+r2.w or
      r1.y > r2.y+r2.h
    )

exports.nextPOT = nextPOT = (n) ->
  pot = 1
  while pot < n
    pot <<= 1
  pot

exports.turnTo = turnTo = (angle, targetAngle, speed) ->
  diff = targetAngle - angle
  diff -= TAU while diff > TAU/2
  diff += TAU while diff < -TAU/2
  if diff > 0
    # turn ccw
    if diff < speed
      angle = targetAngle
    else
      angle += speed
  else
    # turn cw
    if -diff < speed
      angle = targetAngle
    else
      angle -= speed
  angle

exports.MatrixStack = class MatrixStack
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
  transformPoint: (x, y) ->
    tx = @matrix[0]*x + @matrix[3]*y + @matrix[6]
    ty = @matrix[1]*x + @matrix[4]*y + @matrix[7]
    tz = @matrix[2]*x + @matrix[5]*y + @matrix[8]
    return {x:tx/tz, y:ty/tz}
  transformAABB: (bb) ->
    r = @transformPoint bb.x, bb.y
    r = Rect.union r, @transformPoint bb.x+bb.w, bb.y
    r = Rect.union r, @transformPoint bb.x+bb.w, bb.y+bb.h
    r = Rect.union r, @transformPoint bb.x, bb.y+bb.h
    r
