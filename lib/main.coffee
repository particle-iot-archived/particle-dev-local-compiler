whenjs = require 'when'
fs = null
glob = null
path = null
CompositeDisposable = null

DockerManager = null

module.exports = ParticleDevLocalCompiler =
	packageName: 'particle-dev-local-compiler'
	subscriptions: null
	loaded: false
	statusBarDefer: whenjs.defer()
	consolePanelDefer: whenjs.defer()
	consoleToolBar: whenjs.defer()
	coreDefer: whenjs.defer()
	profilesDefer: whenjs.defer()

	activate: (state) ->
		{CompositeDisposable} = require 'atom'
		DockerManager ?= require './docker-manager'
		fs ?= require 'fs-plus'
		glob ?= require 'glob'
		path ?= require 'path'

		# Install packages we depend on
		require('atom-package-deps').install('particle-dev-local-compiler', true)

		@subscriptions = new CompositeDisposable

		@setupDocker()

		whenjs.all([
			@statusBarDefer.promise
			@consolePanelDefer.promise
			@consoleToolBar.promise
			@coreDefer.promise
			@profilesDefer.promise
		]).then =>
			@ready()

		@setupCommands()

	deactivate: ->
		@subscriptions.dispose()

	serialize: ->

	consumeStatusBar: (@statusBar) ->
		@statusBarDefer.resolve @statusBar

	consumeConsolePanel: (@consolePanel) ->
		@consolePanelDefer.resolve @consolePanel

	consumeToolBar: (toolBar) ->
		@toolBar = toolBar @packageName
		@toolBarButton = @toolBar.addButton
			icon: 'checkmark-circled'
			callback: @packageName + ':compile-locally'
			tooltip: 'Compile locally'
			iconset: 'ion'
			priority: 521
		@consoleToolBar.resolve @toolBar

	consumeParticleDev: (@core) ->
		@coreDefer.resolve @core

	consumeProfiles: (@profileManager) ->
		@profilesDefer.resolve @profileManager

	config:
		outputDirectory:
			type: 'string'
			default: 'build'
			description: 'Directory name which will be appended to project directory. Contains logs and other build artefacts.'

		cacheDirectory:
			type: 'string'
			default: '~/.particledev/cache'
			description: 'Directory holding intermediate files between builds.'

	dockerManagerRequired: (callback) ->
		if !@dockerManager
			@setupDocker()
			return
		callback()

	beingLoadedRequired: (callback) ->
		if !@loaded
			return
		callback()

	ready: ->
		@loaded = true

		@core

	setupDocker: ->
		# Fix for "Unable to connect to Docker" error
		childProcess = require 'child_process'
		process.env.PATH = childProcess.execFileSync(process.env.SHELL, ['-i', '-c', 'echo $PATH']).toString().trim()

		@dockerManager = null

		@dockerManager = new DockerManager()
		@dockerManager.onError (error) =>
			if (typeof error != 'string') and (error.errno not in ['ETIMEDOUT', 'ECONNREFUSED'])
				error = error.toString()
				atom.notifications.addError error,
					dismissable: true
			else
				console.error error
				error = """Unable to connect to Docker.\n
				Check if Docker is running (you can use `docker ps -a` in command line).\n
				Reason:
				```#{error}```
				"""
				notification = atom.notifications.addError error,
					dismissable: true

		true

	setupCommands: ->
		@addCommand 'compile-locally', => @compile()

	ensureOutputDir: (projectDir) ->
		outputDir = path.join projectDir, atom.config.get(@packageName + '.outputDirectory')
		fs.makeTreeSync outputDir
		filesToRemove = glob.sync outputDir + '/*.{log,bin}'
		for file in filesToRemove
			fs.removeSync file
		outputDir

	setToolBarButtonProgress: (inProgress) ->
		if inProgress
			@toolBarButton.element.classList.add 'ion-looping'
		else
			@toolBarButton.element.classList.remove 'ion-looping'

	compile: -> @beingLoadedRequired => @dockerManagerRequired => @core.projectRequired =>
		projectDir = @core.getProjectDir()

		outputDir = @ensureOutputDir projectDir
		currentBuildTarget = @profileManager.getLocal 'current-build-target'
		currentPlatform = @profileManager.currentTargetPlatformName.toLowerCase()
		@consolePanel.clear()
		@setToolBarButtonProgress true
		# TODO: Remove old files from output dir

		promise = @dockerManager.compile projectDir, outputDir, {
				PLATFORM_ID: @profileManager.currentTargetPlatform,
				ACCESS_TOKEN: @profileManager.get 'access_token'
			},
			currentBuildTarget
			currentPlatform

		promise.then (result) =>
			@consolePanel.raw fs.readFileSync(path.join(outputDir, 'memory-use.log')).toString()
			# Rename binary based on platform
			outputFile = path.join(projectDir,
				"#{currentPlatform}_#{currentBuildTarget}_firmware_" + (new Date()).getTime() + '.bin')
			fs.moveSync path.join(outputDir, 'firmware.bin'), outputFile

			@setToolBarButtonProgress false
		, (error) =>
			@setToolBarButtonProgress false
			if Array.isArray(error)
				for line in error
					@consolePanel.error line

				@consolePanel.error 'Local compilation failed'
			else
				atom.notifications.addError error

	addCommand: (name, callback, target='atom-workspace') ->
		name = @packageName + ':' + name
		@subscriptions.add atom.commands.add target, name, callback
