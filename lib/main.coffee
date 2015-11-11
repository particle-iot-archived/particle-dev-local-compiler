whenjs = require 'when'
fs = null
glob = null
path = null
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
		path ?= require 'path'

		# Install packages we depend on
		require('atom-package-deps').install('particle-dev-local-compiler', true)

		@subscriptions = new CompositeDisposable

		@setupDocker()
		atom.config.onDidChange =>
			@setupDocker()

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
			description: 'Contents of DOCKER_HOST variable.'

		dockerCertPath:
			type: 'string'
			default: ''
			description: 'Contents of DOCKER_CERT_PATH variable.'

		dockerTlsVerify:
			type: 'boolean'
			default: true
			description: 'True if DOCKER_TLS_VERIFY equals 1.'

		dockerMachineName:
			type: 'string'
			default: 'default'
			description: 'Contents of DOCKER_MACHINE_NAME variable.'

		dockerImageName:
			type: 'string'
			default: 'particle/buildpack-particle-firmware'
			description: 'Name of the Docker Hub image used for compilation'

		outputDirectory:
			type: 'string'
			default: 'build'
			description: 'Directory name which will be appended to project directory. Contains logs and other build artefacts.'

		cacheDirectory:
			type: 'string'
			default: '~/.particledev/cache'
			description: 'Directory holding intermediate files between builds.'

		compileTimeout:
			type: 'integer'
			default: 10
			description: 'Number of seconds to wait before killing image. Adjust this value if you get a lot of "Compilation timed out" errors.'

		showOnlySemverVersions:
			type: 'boolean'
			default: true
			description: 'If true show only X.Y.Z formated versions. Uncheck if you want to access alpha and beta releases.'

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
		LocalCompilerTile = require './local-compiler-tile'
		new LocalCompilerTile @

		@loaded = true

		@particleDev

	setupDocker: ->
		@dockerManager = null
		dockerHost = atom.config.get @packageName + '.dockerHost'
		dockerCertPath = atom.config.get @packageName + '.dockerCertPath'
		if !dockerHost or !dockerCertPath
			error = """
			It looks like you don't have your Docker environment set up in package settings.

			Please follow the instructions on how to set it up.
			"""
			atom.notifications.addError error,
				dismissable: true
				buttons: [{
					text: 'Show instructions'
					onDidClick: ->
						shell = require 'shell'
						shell.openExternal 'https://github.com/spark/particle-dev-local-compiler#installation-steps'
				}, {
					text: 'Show settings'
					onDidClick: ->
						atom.workspace.open 'atom://config/packages/particle-dev-local-compiler'
				}]
			return false

		@dockerManager = new DockerManager(
			atom.config.get @packageName + '.dockerImageName'
			dockerHost
			dockerCertPath
			atom.config.get @packageName + '.dockerTlsVerify'
			atom.config.get @packageName + '.dockerMachineName'
		)
		@dockerManager.onError (error) =>
			if (typeof error != 'string') and (error.errno not in ['ETIMEDOUT', 'ECONNREFUSED'])
				error = error.toString()
				atom.notifications.addError error,
					dismissable: true
			else
				dockerMachineName = atom.config.get @packageName + '.dockerMachineName'
				error = """Unable to connect to Docker.\n
				Check if your Docker machine is running (you can use `docker-machine status #{dockerMachineName}`) and verify Particle Dev Local Compiler package settings are correct.
				"""
				notification = atom.notifications.addError error,
					dismissable: true
					buttons: [{
						text: 'Show settings'
						onDidClick: ->
							atom.workspace.open 'atom://config/packages/particle-dev-local-compiler'
							notification.dismiss()
					}]

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

	compile: -> @beingLoadedRequired => @dockerManagerRequired =>
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
				if stderr.search(/make\: \*\*\* \[.*\] Error/) > -1
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

	updateFirmwareVersions: -> @beingLoadedRequired => @dockerManagerRequired =>
		notification = atom.notifications.addInfo """
			<span>Updating available firmware versions...</span>
			<progress class="inline-block" />""",
			dismissable: true
			detail: 'This may take couple of minutes, depending on your connection speed and amount of new versions (which may be up to 10GB).'
		@dockerManager.pull().then (value) =>
			if notification.isDismissed()
				atom.notifications.addInfo 'Available firmware versions updated'
			else
				notification.dismiss()

	addCommand: (name, callback, target='atom-workspace') ->
		name = @packageName + ':' + name
		@subscriptions.add atom.commands.add target, name, callback
