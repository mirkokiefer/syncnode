
assert = require 'assert'
req = require 'superagent'
{Repository, TreeStore, backend} = require 'synclib'
contentAddressable = require 'content-addressable'
createMemoryStore = require('pluggable-store').server().memory
createApp = require '../lib/index'
{difference} = require 'underscore'

testPort = 3000
url = (path) -> 'http://localhost:' + testPort + path

serverBlobStore = contentAddressable.fileSystem(process.env.HOME+'/syncstore')
serverTreeStore = contentAddressable.memory()
serverHeadStore = createMemoryStore()
serverRepo = new Repository serverTreeStore
app = createApp {blobStore: serverBlobStore, repository: serverRepo, headStore: serverHeadStore}

client1BlobStore = contentAddressable.memory()
client1TreeStore = contentAddressable.memory()
client1Repo = new Repository client1TreeStore
client1Branch = client1Repo.branch()
client1KnownClient2Branch = null

client2BlobStore = contentAddressable.memory()
client2TreeStore = contentAddressable.memory()
client2Repo = new Repository client2TreeStore
client2Branch = client2Repo.branch()
client2KnownClient1Branch = null

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
  describe 'blob storage', ->
    it 'should POST some data and return the hash to GET it', (done) ->
      data = data: "some data"
      req.post(url '/blob').send(data).end (res) ->
        hash = res.body.hash
        req.get(url '/blob/'+hash).end (res) ->
          assert.equal res.body.data, data.data
          done()
  describe 'client1', ->
    it 'should do some local commits and POST the diff to the server', (done) ->
      client1Branch.commit each for each in dataA
      diffHashs = client1Branch.patchHashs()
      diff = client1Repo.patchData diffHashs
      req.post(url '/trees').send(diff.trees).end (res) ->
        for each, i in res.body.treeHashs
          assert.equal each, diffHashs.trees[i]
        done()
    it 'should set its head on the server', (done) ->
      req.put(url '/head/client1').send(hash: client1Branch.head).end (res) ->
        req.get(url '/head/client1').end (res) ->
          assert.equal res.body.hash, client1Branch.head
          done()
  describe 'client2', ->
    it 'should do some commits and push the diff', (done) ->
      client2Branch.commit each for each in dataB
      diff = client2Repo.patchData client2Branch.patchHashs()
      req.post(url '/trees').send(diff.trees).end () -> done()
    it 'should ask for client1\'s head and the common commit', (done) ->
      req.get(url '/head/client1').end (res) ->
        client1Head = res.body.hash
        client2KnownClient1Branch = client2Repo.branch client1Head
        req.get(url '/common-tree?tree1='+client2Branch.head+'&tree2='+client1Head).end (res) ->
          assert.equal res.commonTree, null
          done()
    it 'should ask for the full diff to client1 head since there is no common tree', (done) ->
      req.get(url '/trees?to='+client2KnownClient1Branch.head).end (res) ->
        client2TreeStore.writeAll res.body.trees
        done()
    it 'should do a local merge of client1s diff', ->
      oldHead = client2Branch.head
      head = client2Branch.merge ref: client2KnownClient1Branch
      headTree = client2TreeStore.read head
      assert.equal difference(headTree.ancestors, [client2KnownClient1Branch.head, oldHead]).length, 0
