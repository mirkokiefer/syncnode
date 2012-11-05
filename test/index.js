// Generated by CoffeeScript 1.3.3
(function() {
  var Repository, TreeStore, app, backend, blobStore, contentAddressable, createApp, repo, treeStore, _ref;

  _ref = require('synclib'), Repository = _ref.Repository, TreeStore = _ref.TreeStore, backend = _ref.backend;

  contentAddressable = require('content-addressable');

  createApp = require('../lib/index');

  blobStore = contentAddressable.fileSystem(process.env.HOME + '/syncstore');

  treeStore = contentAddressable.memory();

  repo = new Repository(treeStore);

  app = createApp;

  before(function(done) {
    return app.listen(3000, 'localhost', done);
  });

  after(function(done) {});

  describe('http-interface', function() {
    return describe('/blob', function(done) {
      return console.log(1);
    });
  });

}).call(this);
