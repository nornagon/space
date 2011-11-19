express = require 'express'
sockjs = require 'sockjs'
browserify = require 'browserify'
hat = require 'hat'
{makeWorld, Entity} = require './world'

class Game
  constructor: (@world) ->
    @fps = 30
  update: (dt) -> @world.update dt
  run: ->
    @last_step = Date.now()
    @loop_interval = setInterval =>
      @step()
    , 1000/@fps
  stop: ->
    clearInterval @loop_interval if @loop_interval?
    @loop_interval = null
  step: ->
    now = Date.now()
    dt = now - @last_step
    @last_step = now
    @update dt/1000

world = makeWorld 's'
world.add new Entity 0, 0
e2 = new Entity 500, 500
e2.vx = 100
world.add e2

game = new Game world
game.run()

sockserv = sockjs.createServer sockjs_url: 'http://localhost:8008'
sockserv.on 'connection', (connection) ->
  siteId = hat 30

  connection.write JSON.stringify({siteId, data:world.export()})

  connection.on 'data', (msg) ->
    console.log 'data', msg

  connection.on 'close', -> console.log 'closed'


app = express.createServer()

app.configure ->
    app.use express.static "#{__dirname}/public"
    app.use express.errorHandler dumpExceptions: true, showStack: true
    app.use browserify 'space.coffee', watch:yes

app.get '/', (req, res) ->
  res.send 'hi'

sockserv.installHandlers app, prefix:'[/]sock'
app.listen 8008
console.log 'server listening on 8008'

