path = require 'path'
os = require 'os'

module.exports = (opts = {}) ->
  CUSH_DIR = path.join os.homedir(), '.cush'

  if !opts.port
    opts.sock or= path.join CUSH_DIR, 'cdn.sock'

  opts.log or= require('lodge')
  opts.bucketDir or= path.join CUSH_DIR, 'buckets'
  require('./app')(opts)
