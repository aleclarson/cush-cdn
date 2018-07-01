// Generated by CoffeeScript 2.3.0
var Router, fs, mimeTypes, se;

mimeTypes = require('mime-types');

Router = require('yiss');

se = require('socket-events');

fs = require('saxon');

module.exports = function(app) {
  var api;
  api = new Router;
  api.listen(function(req, res) {
    var bucketId;
    if (bucketId = req.get('x-bucket')) {
      if (req.bucket = app.getBucket(bucketId)) {
        return;
      }
      res.status(404);
      return {
        error: 'Unknown bucket: ' + bucketId
      };
    }
    res.status(400);
    return {
      error: "Missing both 'X-Bucket' and 'X-Project' headers"
    };
  });
  api.GET('/b/assets.json', function(req, res) {
    if (req.accepts('text/event-stream')) {
      req.bucket.events.on('*', se.writer(res));
      return true;
    }
    return req.bucket._assets;
  });
  api.PATCH('/b/assets.json', async function(req) {
    req.bucket.patch((await req.json()));
    return true;
  });
  api.GET('/b/:asset(.+)', async function(req, res) {
    var asset, bytes, name;
    name = req.params.asset;
    asset = req.bucket.get(name);
    asset && (asset = typeof asset === 'string' ? fs.reader(asset) : (await asset(res)));
    if (res.headersSent) {
      return;
    }
    if (!asset) {
      return 404;
    }
    bytes = typeof asset === 'string' ? Buffer.byteLength(asset) : ((await fs.stat(asset.path))).size;
    res.set({
      'Content-Type': mimeTypes.lookup(name) || 'application/octet-stream',
      'Content-Length': bytes,
      'Cache-Control': 'no-store'
    });
    res.flushHeaders();
    if (typeof asset === 'string') {
      res.write(asset);
      return;
    }
    asset.pipe(res);
  });
  return api.bind();
};