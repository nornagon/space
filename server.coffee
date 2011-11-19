express = require 'express'
sockjs = require 'sockjs'
browserify = require 'browserify'

sockserv = sockjs.createServer sockjs_url: 'http://localhost:8008'
sockserv.on 'connection', (connection) ->
  console.log 'connection', connection
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

