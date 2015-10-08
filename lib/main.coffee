ParticleDevLocalCompilerView = require './particle-dev-local-compiler-view'
whenjs = require 'when'
CompositeDisposable = null
DockerManager = null

module.exports = ParticleDevLocalCompiler =
  particleDevLocalCompilerView: null
  modalPanel: null
  subscriptions: null
  statusBarDefer: whenjs.defer()
  particleDevDefer: whenjs.defer()
  profilesDefer: whenjs.defer()

  activate: (state) ->
    {CompositeDisposable} = require 'atom'
    DockerManager ?= require './docker-manager'

    @particleDevLocalCompilerView = new ParticleDevLocalCompilerView(state.particleDevLocalCompilerViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @particleDevLocalCompilerView.getElement(), visible: false)

    @subscriptions = new CompositeDisposable
    @dockerManager = new DockerManager(
      atom.config.get 'particle-dev-local-compiler.dockerHost'
      atom.config.get 'particle-dev-local-compiler.dockerCertPath'
      atom.config.get 'particle-dev-local-compiler.dockerTlsVerify'
      atom.config.get 'particle-dev-local-compiler.dockerMachineName'
    )
    # TODO: Handle Docker errors

    whenjs.all([
      @statusBarDefer.promise
      @particleDevDefer.promise
      @profilesDefer.promise
    ]).then =>
      @ready()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @particleDevLocalCompilerView.destroy()

  serialize: ->
    particleDevLocalCompilerViewState: @particleDevLocalCompilerView.serialize()

  config:
    dockerHost:
      type: 'string'
      default: ''

    dockerCertPath:
      type: 'string'
      default: ''

    dockerTlsVerify:
      type: 'boolean'
      default: true

    dockerMachineName:
      type: 'string'
      default: 'default'

  ready: ->
    LocalCompilerTile = require './local-compiler-tile'
    new LocalCompilerTile @

  consumeStatusBar: (@statusBar) ->
    @statusBarDefer.resolve @statusBar

  consumeParticleDev: (@particleDev) ->
    @particleDevDefer.resolve @particleDev

  consumeProfiles: (@profileManager) ->
    @profilesDefer.resolve @profileManager
