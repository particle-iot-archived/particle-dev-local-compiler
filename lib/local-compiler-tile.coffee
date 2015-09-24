{View} = require 'atom-space-pen-views'
{CompositeDisposable} = require 'atom'

module.exports =
class LocalCompilerTile extends View
	@content: ->
		@span type: 'button', class: 'icon icon-tag inline-block'
		@span	'v0.4.5'

	initialize: (@statusBar) ->
		@subscriptions = new CompositeDisposable()

		@on 'click', -> atom.workspace.open('atom://release-notes')

		@subscriptions.add atom.tooltips.add(@element, title: 'Click to change local compile firmware version')
		@attach()

	attach: ->
		console.log 'ATTACH'
		@statusBar.addLeftTile(item: @, priority: 200)

	detached: ->
		@subscriptions?.dispose()
