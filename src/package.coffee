fs = require('fs')
path = require('path')
_ = require('underscore')
config = require('./config')

class Package
  constructor: (jsonPath) ->
    @path = path.dirname(jsonPath)
    @userPackage = path.normalize(@path).startsWith(path.normalize(config.userPackagePath))

    info = JSON.parse(fs.readFileSync(jsonPath))

    if info.name?
      @name = info.name
    else
      throw new Error 'package name required'

    if info.main?
      @main = info.main
    else
      throw new Error 'package main required'

    @description = info.description ? ''
    @version = info.version ? '0.0.1'
    @config = dripcap.profile.getPackageConfig @name
    @_reset()

  _reset: ->
    @_promise =
      new Promise (resolve) =>
        @_resolve = resolve
      .then =>
        new Promise (resolve, reject) =>
          req = path.resolve(@path, @main)
          res = null
          try
            klass = require(req)
            @root = new klass(@)
            res = @root.activate()
            @updateTheme(dripcap.theme.scheme)

          catch e
            reject(e)
            return

          if res instanceof Promise
            res.then => resolve(@)
          else
            resolve(@)

  load: ->
    @_promise

  activate: ->
    @_resolve()

  updateTheme: (theme) ->
    @load().then =>
      if @root?.updateTheme?
        @root.updateTheme theme

  renderPreferences: ->
    if @root?.renderPreferences?
      @root.renderPreferences()
    else
      null

  deactivate: ->
    @load().then =>
      new Promise (resolve, reject) =>
        try
          @root.deactivate()
          @root = null
          @_reset()
          for key of require.cache
            if key.startsWith(@path)
              delete require.cache[key]
        catch e
          reject(e)
          return
        resolve(@)

module.exports = Package