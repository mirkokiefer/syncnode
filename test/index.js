// Generated by CoffeeScript 1.3.3
(function() {
  var Repository, TreeStore, app, assert, backend, client1BlobStore, client1Branch, client1KnownClient2Branch, client1Repo, client1TreeStore, client2BlobStore, client2Branch, client2KnownClient1Branch, client2Repo, client2TreeStore, contentAddressable, createApp, createMemoryStore, dataA, dataB, difference, req, serverBlobStore, serverHeadStore, serverRepo, serverTreeStore, testPort, url, _ref;

  assert = require('assert');

  req = require('superagent');

  _ref = require('synclib'), Repository = _ref.Repository, TreeStore = _ref.TreeStore, backend = _ref.backend;

  contentAddressable = require('content-addressable');

  createMemoryStore = require('pluggable-store').server().memory;

  createApp = require('../lib/index');

  difference = require('underscore').difference;

  testPort = 3000;

  url = function(path) {
    return 'http://localhost:' + testPort + path;
  };

  serverBlobStore = contentAddressable.fileSystem(process.env.HOME + '/syncstore');

  serverTreeStore = contentAddressable.memory();

  serverHeadStore = createMemoryStore();

  serverRepo = new Repository(serverTreeStore);

  app = createApp({
    blobStore: serverBlobStore,
    repository: serverRepo,
    headStore: serverHeadStore
  });

  client1BlobStore = contentAddressable.memory();

  client1TreeStore = contentAddressable.memory();

  client1Repo = new Repository(client1TreeStore);

  client1Branch = client1Repo.branch();

  client1KnownClient2Branch = null;

  client2BlobStore = contentAddressable.memory();

  client2TreeStore = contentAddressable.memory();

  client2Repo = new Repository(client2TreeStore);

  client2Branch = client2Repo.branch();

  client2KnownClient1Branch = null;

  dataA = [
    {
      'a': "hash1",
      'b/c': "hash2",
      'b/d': "hash3"
    }, {
      'a': "hash4",
      'b/c': "hash5",
      'b/e': "hash6",
      'b/f/g': "hash7"
    }, {
      'b/e': "hash8"
    }
  ];

  dataB = [
    {
      'b/h': "hash9"
    }, {
      'c/a': "hash10"
    }, {
      'a': "hash11",
      'u': "hash12"
    }, {
      'b/c': "hash13",
      'b/e': "hash14",
      'b/f/a': "hash15"
    }
  ];

  before(function(done) {
    return app.listen(testPort, 'localhost', done);
  });

  after(function(done) {
    return serverBlobStore.store.adapter["delete"](done);
  });

  describe('http-interface', function() {
    describe('blob storage', function() {
      return it('should POST some data and return the hash to GET it', function(done) {
        var data;
        data = {
          data: "some data"
        };
        return req.post(url('/blob')).send(data).end(function(res) {
          var hash;
          hash = res.body.hash;
          return req.get(url('/blob/' + hash)).end(function(res) {
            assert.equal(res.body.data, data.data);
            return done();
          });
        });
      });
    });
    describe('client1', function() {
      it('should do some local commits and POST the diff to the server', function(done) {
        var diff, diffHashs, each, _i, _len;
        for (_i = 0, _len = dataA.length; _i < _len; _i++) {
          each = dataA[_i];
          client1Branch.commit(each);
        }
        diffHashs = client1Branch.patchHashs();
        diff = client1Repo.patchData(diffHashs);
        return req.post(url('/trees')).send(diff.trees).end(function(res) {
          var i, _j, _len1, _ref1;
          _ref1 = res.body.treeHashs;
          for (i = _j = 0, _len1 = _ref1.length; _j < _len1; i = ++_j) {
            each = _ref1[i];
            assert.equal(each, diffHashs.trees[i]);
          }
          return done();
        });
      });
      return it('should set its head on the server', function(done) {
        return req.put(url('/head/client1')).send({
          hash: client1Branch.head
        }).end(function(res) {
          return req.get(url('/head/client1')).end(function(res) {
            assert.equal(res.body.hash, client1Branch.head);
            return done();
          });
        });
      });
    });
    return describe('client2', function() {
      it('should do some commits and push the diff', function(done) {
        var diff, each, _i, _len;
        for (_i = 0, _len = dataB.length; _i < _len; _i++) {
          each = dataB[_i];
          client2Branch.commit(each);
        }
        diff = client2Repo.patchData(client2Branch.patchHashs());
        return req.post(url('/trees')).send(diff.trees).end(function() {
          return done();
        });
      });
      it('should ask for client1\'s head and the common commit', function(done) {
        return req.get(url('/head/client1')).end(function(res) {
          var client1Head;
          client1Head = res.body.hash;
          client2KnownClient1Branch = client2Repo.branch(client1Head);
          return req.get(url('/common-tree?tree1=' + client2Branch.head + '&tree2=' + client1Head)).end(function(res) {
            assert.equal(res.commonTree, null);
            return done();
          });
        });
      });
      it('should ask for the full diff to client1 head since there is no common tree', function(done) {
        return req.get(url('/trees?to=' + client2KnownClient1Branch.head)).end(function(res) {
          client2TreeStore.writeAll(res.body.trees);
          return done();
        });
      });
      return it('should do a local merge of client1s diff', function() {
        var head, headTree, oldHead;
        oldHead = client2Branch.head;
        head = client2Branch.merge({
          ref: client2KnownClient1Branch
        });
        headTree = client2TreeStore.read(head);
        return assert.equal(difference(headTree.ancestors, [client2KnownClient1Branch.head, oldHead]).length, 0);
      });
    });
  });

}).call(this);
