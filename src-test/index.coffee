
assert = require 'assert'
req = require 'superagent'
{Repository, TreeStore, backend} = require 'synclib'
contentAddressable = require 'content-addressable'
createApp = require '../lib/index'

blobStore = contentAddressable.fileSystem(process.env.HOME+'/syncstore')
treeStore = contentAddressable.memory()
repo = new Repository treeStore
app = createApp {blobStore: blobStore, repository: repo}

url = (path) -> 'http://localhost:3000' + path
before (done) -> app.listen 3000, 'localhost', done
after (done) -> blobStore.store.adapter.delete done

describe 'http-interface', ->
  describe '/blob', ->
    it 'should POST some data and return the hash to GET it', (done) ->
      data = data: "some data"
      req.post(url '/blob').send(data).end (res) ->
        hash = res.body.hash
        req.get(url '/blob/'+hash).set('Accept', 'application/json').end (res) ->
          assert.equal res.body.data, data.data
          done()