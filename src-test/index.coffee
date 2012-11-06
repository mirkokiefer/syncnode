
assert = require 'assert'
req = require 'superagent'
{Repository, TreeStore, backend} = require 'synclib'
contentAddressable = require 'content-addressable'
createApp = require '../lib/index'

testPort = 3000
url = (path) -> 'http://localhost:' + testPort + path

serverBlobStore = contentAddressable.fileSystem(process.env.HOME+'/syncstore')
serverTreeStore = contentAddressable.memory()
serverRepo = new Repository serverTreeStore
app = createApp {blobStore: serverBlobStore, repository: serverRepo}

client1BlobStore = contentAddressable.memory()
client1TreeStore = contentAddressable.memory()
client1Repo = new Repository client1TreeStore
client1Branch = client1Repo.branch()

client2BlobStore = contentAddressable.memory()
client2TreeStore = contentAddressable.memory()
client2Repo = new Repository client2TreeStore
client2Branch = client2Repo.branch()

dataA = [
  {'a': "hash1", 'b/c': "hash2", 'b/d': "hash3"}
  {'a': "hash4", 'b/c': "hash5", 'b/e': "hash6", 'b/f/g': "hash7"}
  {'b/e': "hash8"}
]

dataB = [
  {'b/h': "hash9"}
  {'c/a': "hash10"}
  {'a': "hash11", 'u': "hash12"}
  {'b/c': "hash13", 'b/e': "hash14", 'b/f/a': "hash15"}
]

before (done) -> app.listen testPort, 'localhost', done
after (done) -> serverBlobStore.store.adapter.delete done

describe 'http-interface', ->
  describe '/blob', ->
    it 'should POST some data and return the hash to GET it', (done) ->
      data = data: "some data"
      req.post(url '/blob').send(data).end (res) ->
        hash = res.body.hash
        req.get(url '/blob/'+hash).set('Accept', 'application/json').end (res) ->
          assert.equal res.body.data, data.data
          done()
  describe '/trees', ->
    it 'should do some local commits on client1 and POST the diff to the server', (done) ->
      for each in dataA
        client1Branch.commit each
      diffHashs = client1Branch.patchHashsSince [null]
      diff = client1Branch.patchSince [null]
      req.post(url '/trees').send(diff.trees).end (res) ->
        for each, i in res.body.treeHashs
          assert.equal each, diffHashs.trees[i]
        done()