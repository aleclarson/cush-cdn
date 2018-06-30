{evalFile, sha256} = require 'cush/utils'
Bucket = require './Bucket'
slush = require 'slush'
cush = require 'cush'
path = require 'path'
fs = require 'saxon/sync'

module.exports = (opts) ->
  {log, bucketDir} = opts

  buckets = Object.create null
  projects = Object.create null

  app = slush opts

  app.ready ->
    log log.coal('[cush-cdn]'), log.lgreen('Server ready!')

  if opts.sock
    app.on 'close', ->
      try fs.remove opts.sock

  app.pipe require('./api')(app)

  app.loadProject = (root) ->
    return if projects[root]
    projects[root] =
      project = cush.project root

    pack = project.root
    skip = evalFile pack.resolve 'assets/.cushignore'
    skip = skip and skip.split('\n') or []
    skip.push '/.cushignore', '.DS_Store', '*.swp'

    bucket = @loadBucket pack.data.name,
      root: pack.resolve 'assets'
      skip: skip

    {bundles} = project.config
    Object.keys(bundles).forEach (main) ->
      opts = getOptions bundles[main]
      bundle = cush.bundle path.join(root, main),
        target: opts.target
        dev: true

      log log.lyellow('Loading bundle:'), bucket.id + '/' + main
      log ' ', opts

      bucket.put opts.name, (res) ->
        result = await bundle.read()
        if !bundle.missed.length
          res.send result
          return

        error =
          code: 'BAD_IMPORTS'
          root: bundle.root.path
          imports: bundle.missed.map ([mod, i]) ->
            {ref, line} = mod.deps[i]
            {ref, line, parent: bundle.relative mod}

        res.status 400
        res.send error

        app.emit 'error', error
        return

  app.dropProject = (root) ->
    if project = projects[root]
      delete projects[root]
      project.drop()
    !!project

  app.getBucket = (bucketId) ->
    buckets[bucketId] or null

  app.loadBucket = (bucketId, opts) ->
    if !opts or typeof opts.root isnt 'string'
      throw Error '`opts.root` must be a string'

    if bucket = buckets[bucketId]
      return bucket if bucket.root is opts.root
      throw Error """
        Bucket name '#{bucketId}' is taken by:
          #{bucket.root}
      """

    log log.lyellow('Loading bucket:'), bucketId
    log ' ', opts

    opts.dest = path.join bucketDir, bucketId
    buckets[bucketId] = bucket = new Bucket bucketId, opts
    return bucket

  app.dropBucket = (bucketId) ->
    if bucket = buckets[bucketId]
      fs.remove bucket.dest, true
      delete buckets[bucketId]
    else false

  app

getOptions = (value) ->
  if typeof value is 'string'
    name = value
    target = /\.([^./]+)\.[^./]+$/.exec value
    if !target and= target[1]
      throw Error "Missing target: '#{value}'"
    return {name, target}
  if !value.target
    throw Error "Missing `target` option: #{JSON.stringify value}"
  return value
