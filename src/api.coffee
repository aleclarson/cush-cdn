mimeTypes = require 'mime-types'
Router = require 'yiss'
se = require 'socket-events'
fs = require 'saxon'

module.exports = (app) ->
  api = new Router

  api.listen (req, res) ->

    if bucketId = req.get 'x-bucket'
      return if req.bucket = app.getBucket bucketId

      res.status 404
      return error: 'Unknown bucket: ' + bucketId

    res.status 400
    return error: "Missing both 'X-Bucket' and 'X-Project' headers"

  api.GET '/b/assets.json', (req, res) ->
    if req.accepts 'text/event-stream'
      req.bucket.events.on '*', se.writer res
      return true
    return req.bucket._assets

  api.PATCH '/b/assets.json', (req) ->
    req.bucket.patch await req.json()
    return true

  api.GET '/b/:asset(.+)', (req, res) ->
    name = req.params.asset

    asset = @get name
    asset and=
      if typeof asset is 'string'
      then fs.reader asset
      else await asset res

    return if res.headersSent
    return 404 if !asset

    bytes =
      if typeof asset is 'string'
      then Buffer.byteLength asset
      else (await fs.stat asset.path).size

    res.set
      'Content-Type': mimeTypes.lookup(name) or 'application/octet-stream'
      'Content-Length': bytes
      'Cache-Control': 'no-store'
    res.flushHeaders()

    if typeof asset is 'string'
      res.write asset
      return

    asset.pipe res
    return

  api.bind()
