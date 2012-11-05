{Repository, TreeStore, backend} = require 'synclib'
contentAddressable = require 'content-addressable'
createApp = require '../lib/index'

blobStore = contentAddressable.fileSystem(process.env.HOME+'/syncstore')
treeStore = contentAddressable.memory()
repo = new Repository treeStore
app = createApp

before (done) -> app.listen 3000, 'localhost', done
after (done) -> 
describe 'http-interface', ->
  describe '/blob', (done) ->
    console.log 1