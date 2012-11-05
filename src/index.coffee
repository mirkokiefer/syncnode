{Repository, TreeStore, backend} = require 'synclib'
contentAddressable = require 'content-addressable'
express = require 'express'
_ = require 'underscore'
async = require 'async'

createApp = ({blobStore, repository}) ->
  app = express()
  app.configure ->
    app.use express.cookieParser()
    app.use express.cookieSession({secret: 'SyncStore'})
    app.use express.bodyParser()
    app.use express.methodOverride()
    app.use app.router

  app.configure 'development', -> app.use express.errorHandler dumpExceptions: true, showStack: true
  app.configure 'production', -> app.use express.errorHandler()

  app.get '/', (req, res) -> res.send ok: 'SyncStore is running'

  app.get '/changes', (req, res) ->

  app.get '/common-tree', (req, res) ->

  app.get '/trees', (req, res) ->

  app.post '/trees', (req, res) ->

  app.put '/head/:branch', (req, res) ->

  app.get '/head/:branch', (req, res) ->

  app.post '/blob', (req, res) ->

  app.get '/blob/:hash', (req, res) ->

module.exports = createApp