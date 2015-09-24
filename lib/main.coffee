ParticleDevLocalCompilerView = require './particle-dev-local-compiler-view'
{CompositeDisposable} = require 'atom'

module.exports = ParticleDevLocalCompiler =
  particleDevLocalCompilerView: null
  modalPanel: null
  subscriptions: null

  activate: (state) ->
    @particleDevLocalCompilerView = new ParticleDevLocalCompilerView(state.particleDevLocalCompilerViewState)
    @modalPanel = atom.workspace.addModalPanel(item: @particleDevLocalCompilerView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'particle-dev-local-compiler:toggle': => @toggle()

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @particleDevLocalCompilerView.destroy()

    @statusBarTile?.destroy()
    @statusBarTile = null

  serialize: ->
    particleDevLocalCompilerViewState: @particleDevLocalCompilerView.serialize()

  toggle: ->
    console.log 'ParticleDevLocalCompiler was toggled!'

    if @modalPanel.isVisible()
      @modalPanel.hide()
    else
      @modalPanel.show()

  consumeStatusBar: (statusBar) ->
    @statusBar = statusBar
    console.log 'CONSUME'

    LocalCompilerTile = require './local-compiler-tile'
    new LocalCompilerTile(@statusBar)
