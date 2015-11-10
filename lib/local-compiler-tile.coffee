{View} = require 'atom-space-pen-views'
CompositeDisposable = null
SelectTargetVersionView = null

module.exports =
class LocalCompilerTile extends View
	@content: ->
		@span class: 'inline-block', =>
			@span type: 'button', class: 'icon icon-tag inline-block', outlet: 'targetVersion', 'Unknown'

	initialize: (@main) ->
		{CompositeDisposable} = require 'atom'

		@subscriptions = new CompositeDisposable()

		@subscriptions.add @targetVersion.on 'click', =>
			SelectTargetVersionView ?= require './select-target-version-view'
			@selectTargetVersionView ?= new SelectTargetVersionView(@main)
			@selectTargetVersionView.show()
		@subscriptions.add atom.tooltips.add(@targetVersion, title: 'Click to change local compile firmware version')

		@subscriptions.add @main.profileManager.on 'current-local-target-version-changed', (newTargetVersion) =>
			@targetVersion.text newTargetVersion

		@main.dockerManager?.getLatestSemVerVersion().then (version) =>
			@targetVersion.text version

		@attach()

	attach: ->
		@main.statusBar.addLeftTile(item: @, priority: 201)

	detached: ->
		@subscriptions?.dispose()
