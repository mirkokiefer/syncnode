
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
      req.post(url '/trees').send(diff.trees).end () -> done()
    it 'should ask for client1\'s head and the common commit', (done) ->
      req.get(url '/head/client1').end (res) ->
        client2.remotes.client1 = res.body.hash
        req.get(url '/common-tree?tree1='+client2.branch.head+'&tree2='+client2.remotes.client1).end (res) ->
          assert.equal res.commonTree, null
          done()
    it 'should ask for the full diff to client1 head since there is no common tree', (done) ->
      req.get(url '/trees?to='+client2.remotes.client1).end (res) ->
        client2.treeStore.writeAll res.body.trees
        done()
    it 'should do a local merge of client1s diff', ->
      oldHead = client2.branch.head
      head = client2.branch.merge ref: client2.remotes.client1
      headTree = client2.treeStore.read head
      assert.equal difference(headTree.ancestors, [client2.remotes.client1, oldHead]).length, 0
    it 'should push its new diff to the server', ->
      ###
      this is trickier than I thought:
      diff1 = the diff between my last push and my current head
      this includes redundant information
      diff2 = diff between my last push and client1 head
      diff to be pushed = diff1 - diff2
      right?
      I should update my local remotes only after having pulled the diff
      then I can use it to compute diff2 safely - otherwise I might lack data
      if we consider a multi-master setup its more complex:
        I would have to check if the servers remote head is more or less advanced
        the safest way is to always first do a pull - but we also dont want to waste time to do pushs...
        if the server has an ancestor of my client1 head:
          its simple - we just use the servers client1 head to compute diff2
        if the server is further than my client1 head:
          we just use our local one to push
        if the server is on a fork
          we first have to find out that he is - by doing a common-tree call
        maybe thats always the best thing to do - call common-tree to find out what to use as client1 head
        I have to think about this - especially on how to scale this to many peers.
        I might have to rewrite branch.patch to let me compute a patch for multiple branches.
      ###
      
