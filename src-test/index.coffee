
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

class Client
  constructor: ->
    @blobStore = contentAddressable.memory()
    @treeStore = contentAddressable.memory()
    @repo = new Repository @treeStore
    @branch = @repo.branch()
    @remotes = {}

client1 = new Client()
client2 = new Client()

dataA = [
  {'a': "hashA 0.0", 'b/c': "hashA 0.1", 'b/d': "hashA 0.2"}
  {'a': "hashA 1.0", 'b/c': "hashA 1.1", 'b/e': "hashA 1.2", 'b/f/g': "hashA 1.3"}
  {'b/e': "hashA 2.0"}
]
dataB = [
  {'b/h': "hashB 0.0"}
  {'c/a': "hashB 1.0"}
  {'a': "hashB 2.0", 'u': "hashB 2.1"}
  {'b/c': "hashB 3.0", 'b/e': "hashB 3.1", 'b/f/a': "hashB 3.2"}
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
      client1.branch.commit each for each in dataA
      diffHashs = client1.branch.patchHashs()
      diff = client1.repo.patchData diffHashs
      req.post(url '/trees').send(diff.trees).end (res) ->
        for each, i in res.body.treeHashs
          assert.equal each, diffHashs.trees[i]
        client1.remotes.client1 = client1.branch.head
        done()
    it 'should set its head on the server', (done) ->
      req.put(url '/head/client1').send(hash: client1.branch.head).end (res) ->
        req.get(url '/head/client1').end (res) ->
          assert.equal res.body.hash, client1.branch.head
          done()
  describe 'client2', ->
    it 'should do some commits and push the diff', (done) ->
      client2.branch.commit each for each in dataB
      diff = client2.repo.patchData client2.branch.patchHashs()
      req.post(url '/trees').send(diff.trees).end () ->
        client2.remotes.client2 = client2.branch.head
        done()
    it 'should ask for client1\'s head', (done) ->
      req.get(url '/head/client1').end (res) ->
        client2.remotes.client1 = res.body.hash
        done()
    it 'should ask for the patch to client1 head', (done) ->
      req.get(url '/trees?from='+client2.remotes.client2+'&to='+client2.remotes.client1).end (res) ->
        client2.treeStore.writeAll res.body.trees
        done()
    it 'should do a local merge of client1s diff', ->
      oldHead = client2.branch.head
      head = client2.branch.merge ref: client2.remotes.client1
      headTree = client2.treeStore.read head
      assert.equal difference(headTree.ancestors, [client2.remotes.client1, oldHead]).length, 0
    it 'should push its new diff to the server', (done) ->
      patch = client2.branch.patchHashs from: client2.remotes.client2
      for remote, remoteHead of client2.remotes
        knownPatch = client2.repo.patchHashs from: client2.remotes.client2, to: remoteHead
        patch.trees = difference patch.trees, knownPatch.trees
        patch.data = difference patch.data, knownPatch.data
      patchData = client2.repo.patchData patch
      req.post(url '/trees').send(patchData.trees).end ->
        client2.remotes.client2 = client2.branch.head
        done()
    it 'should update its head on the server', (done) ->
      req.put(url '/head/client2').send(hash: client2.branch.head).end (res) ->
        done()
  describe 'client1 - step 2', ->
    it 'should ask for client2 head and fetch the patch', (done) ->
      req.get(url '/head/client2').end (res) ->
        client1.remotes.client2 = res.body.hash
        req.get(url '/trees?from='+client1.remotes.client1+'&to='+client1.remotes.client2).end (res) ->
          client1.treeStore.writeAll res.body.trees
          done()
    it 'does a local fast-forward merge', ->
      head = client1.branch.merge ref: client1.remotes.client2
      assert.equal head, client1.remotes.client2

      
