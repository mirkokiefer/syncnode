express = require 'express'
_ = require 'underscore'
async = require 'async'

createApp = ({blobStore, repository, headStore}) ->
  app = express()
  app.configure ->
    app.use express.cookieParser()
    app.use express.cookieSession({secret: 'SyncStore'})
    app.use express.bodyParser()
    app.use express.methodOverride()
    app.use express.query()
    app.use app.router

  app.configure 'development', -> app.use express.errorHandler dumpExceptions: true, showStack: true
  app.configure 'production', -> app.use express.errorHandler()

  app.get '/', (req, res) -> res.send ok: 'SyncStore is running'

  app.get '/changes', (req, res) ->

  app.get '/trees', (req, res) ->
    patch = repository.patchData repository.patchHashs from: req.query.from, to: req.query.to
    res.send patch

  app.post '/trees', (req, res) ->
    repository.store.writeAll req.body, (err, hashs) ->
      res.send treeHashs: hashs

  app.put '/head/:branch', (req, res) ->
    headStore.write req.params.branch, req.body.hash
    res.send ok: 'success'

  app.get '/head/:branch', (req, res) ->
    res.send hash: headStore.read req.params.branch

  app.post '/blob', (req, res) ->
    blobStore.write JSON.stringify(req.body), (err, hash) ->
      res.send hash: hash

  app.get '/blob/:hash', (req, res) ->
    blobStore.read req.params.hash, (err, data) ->
      res.send JSON.parse(data)
  app

module.exports = createApp