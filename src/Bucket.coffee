{sha256} = require 'cush/utils'
sortObject = require 'sort-obj'
path = require 'path'
wch = require 'wch'
fs = require 'saxon/sync'
se = require 'socket-events'

emptyArray = []
noop = ->

# Buckets are local caches for project assets.
class Bucket
  constructor: (id, opts) ->
    @id = id
    @root = opts.root
    @dest = opts.dest
    @only = opts.only or emptyArray
    @skip = opts.skip or emptyArray
    @events = se.events()
    @_assets = @_loadAssets()
    @

  has: (name) ->
    @_assets[name]?

  get: (name) ->
    if value = @_assets[name]
      value = name if value is true
      @_dest value

  patch: (values) ->
    for name, value of values

      if value is null
        @delete name
        continue

      prev = @_assets[name]
      @_assets[name] = value

      if prev
        prev = name if prev is true
        prev = @_dest prev

        value = name if value is true
        fs.rename prev, @_dest value

      event = prev and 'change' or 'add'
      @events.emit event, {name, value}

    @_save()
    return

  put: (name, value) ->
    prev = @_assets[name]
    if prev is true
      prev = name
      value or= true

    if typeof value isnt 'function'
      file = fs.read path.join(@root, name), null

      if value is true
        value = name
      else
        ext = path.extname name
        value = name.slice(0, 1 - ext.length) + sha256(file, 10) + ext
        return if value is prev

      dest = @_dest value
      fs.mkdir path.dirname dest if !prev
      fs.write dest, file

    fs.remove @_dest(prev) if prev
    @_assets[name] = value
    @_save()

    event = prev and 'change' or 'add'
    @events.emit event, {name, value}
    return

  delete: (name) ->
    if dest = @_assets[name]
      dest = name if dest is true
      dest = @_dest dest

      # Remove the file, and its directory (if empty)
      fs.remove dest
      try fs.remove path.dirname(dest)

      delete @_assets[name]
      @_save()

      @events.emit 'delete', {name}
      return

  query: (opts = {}) ->
    opts.only or= @only
    opts.skip = opts.skip and @skip.concat(opts.skip) or @skip
    wch.query @root, opts

  _save: ->
    saveJson @_dest('assets.json'), @_assets

  _dest: (name) ->
    path.join @dest, name

  _resolve: (...args) ->
    name = path.relative @root, path.join ...args
    if name[0] isnt '.' then name else null

  _loadAssets: ->
    fs.mkdir @dest

    manifest = @_dest 'assets.json'
    if fs.isFile manifest
      assets = JSON.parse fs.read manifest
      query = @query
        since: fs.stat(manifest).mtime

    else
      assets = {}
      assets['assets.json'] = true
      query = @query()

    @_save = noop
    query.then (files) =>
      {root} = files
      files.forEach (file) =>
        name = @_resolve root, file.name
        if file.exists
        then @put name
        else @delete name

      # Save even if no changes were made.
      delete @_save
      @_save()

      @watcher = wch.stream root
      .on 'data', (file) =>
        if name = @_resolve file.path
          if file.exists then @put name else @delete name

    .catch (err) =>
      @events.emit 'error', err

    return assets

module.exports = Bucket

saveJson = (file, json) ->
  fs.write file, JSON.stringify sortObject(json), null, 2
