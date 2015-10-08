{SelectView} = require 'particle-dev-views'

$$ = null
semver = null

module.exports =
class SelectTargetVersionView extends SelectView
	initialize: (@main) ->
		super

		{$$} = require 'atom-space-pen-views'
		@prop 'id', 'particle-dev-select-target-version-view'

	show: =>
		@setItems []
		@setLoading 'Listing versions...'
		@listVersions()
		super

	viewForItem: (item) ->
		 $$ -> @li(item)

	confirmed: (item) ->
		@main.profileManager.setLocal 'current-local-target-version', item
		@hide()

	getFilterKey: ->
		'name'

	listVersions: ->
		@main.dockerManager.getSemVerVersions().then (versions) =>
			@setItems versions
		, (error) =>
			atom.notifications.addError error
