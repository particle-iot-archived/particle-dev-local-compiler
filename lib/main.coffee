whenjs = require 'when'
fs = null
glob = null
CompositeDisposable = null
DockerManager = null

module.exports = ParticleDevLocalCompiler =
	packageName: 'particle-dev-local-compiler'
	particleDevLocalCompilerView: null
	modalPanel: null
	subscriptions: null
	loaded: false
	statusBarDefer: whenjs.defer()
	consolePanelDefer: whenjs.defer()
	consoleToolBar: whenjs.defer()
	particleDevDefer: whenjs.defer()
	profilesDefer: whenjs.defer()

	activate: (state) ->
		{CompositeDisposable} = require 'atom'
		DockerManager ?= require './docker-manager'
		fs ?= require 'fs-plus'
		glob ?= require 'glob'

		# Install packages we depend on
		require('atom-package-deps').install('particle-dev-local-compiler', true)

		@subscriptions = new CompositeDisposable
		if !@setupDocker()
			# We can't do anything without Docker
			return

		whenjs.all([
			@statusBarDefer.promise
			@consolePanelDefer.promise
			@consoleToolBar.promise
			@particleDevDefer.promise
			@profilesDefer.promise
		]).then =>
			@ready()

		@setupCommands()

	deactivate: ->
		@modalPanel.destroy()
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
			priority: 52
		@consoleToolBar.resolve @toolBar

	consumeParticleDev: (@particleDev) ->
		@particleDevDefer.resolve @particleDev

	consumeProfiles: (@profileManager) ->
		@profilesDefer.resolve @profileManager

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

		outputDirectory:
			type: 'string'
			default: 'build'

		cacheDirectory:
			type: 'string'
			default: '~/.particledev/cache'

		compileTimeout:
			type: 'integer'
			default: 5

	ready: ->
		LocalCompilerTile = require './local-compiler-tile'
		new LocalCompilerTile @

		@loaded = true

		@particleDev

	setupDocker: ->
		dockerHost = atom.config.get @packageName + '.dockerHost'
		dockerCertPath = atom.config.get @packageName + '.dockerCertPath'
		if !dockerHost or !dockerCertPath
			error = """
			It looks like you don't have your Docker environment set up.

			Go to https://docs.particle.io/guide/tools-and-features/dev/#local-compilation and follow instructions on how to set it up.
			"""
			atom.notifications.addError error,
				dismissable: true
			return false

		@dockerManager = new DockerManager(
			dockerHost
			dockerCertPath
			atom.config.get @packageName + '.dockerTlsVerify'
			atom.config.get @packageName + '.dockerMachineName'
		)
		@dockerManager.onError (error) =>
			atom.notifications.addError error,
				dismissable: true

		true

	setupCommands: ->
		@addCommand 'compile-locally', => @compile()
		@addCommand 'update-firmware-versions', => @updateFirmwareVersions()

	ensureOutputDir: (projectDir) ->
		outputDir = path.join projectDir, atom.config.get(@packageName + '.outputDirectory')
		fs.makeTreeSync outputDir
		filesToRemove = glob.sync outputDir + '/*.{log,bin}'
		for file in filesToRemove
			fs.removeSync file
		outputDir

	compile: ->
		if @loaded
			projectDir = @particleDev.getProjectDir()
			if projectDir != null
				outputDir = @ensureOutputDir projectDir
				cacheDir = fs.absolute atom.config.get(@packageName + '.cacheDirectory')
				fs.makeTreeSync cacheDir
				@consolePanel.clear()
				@toolBarButton.addClass 'ion-looping'

				promise = @dockerManager.run projectDir, outputDir, cacheDir, {
						PLATFORM_ID: @profileManager.currentTargetPlatform
					},
					@profileManager.getLocal 'current-local-target-version'

				compileErrorHandler = (error) =>
					stderr = path.join(outputDir, 'stderr.log')
					if fs.existsSync stderr
						@consolePanel.raw fs.readFileSync(stderr).toString()
					else
						atom.notifications.addError error.toString()

				promise.then (result) =>
					@toolBarButton.removeClass 'ion-looping'
					# FIXME: Hack for buildpacks returning 0 even when failed
					log = path.join(outputDir, 'stderr.log')
					stderr = fs.readFileSync(log).toString()
					if stderr.indexOf('make: *** [user] Error') > -1
						compileErrorHandler 'Compilation failed'
					else
						@consolePanel.raw fs.readFileSync(path.join(outputDir, 'memory-use.log')).toString()
						# Rename binary based on platform
						outputFile = path.join(projectDir,
							@profileManager.currentTargetPlatformName.toLowerCase() +
							'_firmware_' + (new Date()).getTime() + '.bin')
						fs.moveSync path.join(outputDir, 'firmware.bin'), outputFile
				, (error) =>
					@toolBarButton.removeClass 'ion-looping'
					compileErrorHandler error

	updateFirmwareVersions: ->
		atom.notifications.addInfo 'Updating available firmware versions...'
		@dockerManager.pull().then (value) =>
			atom.notifications.addInfo 'Available firmware versions updated'

	addCommand: (name, callback, target='atom-workspace') ->
		name = @packageName + ':' + name
		@subscriptions.add atom.commands.add target, name, callback
