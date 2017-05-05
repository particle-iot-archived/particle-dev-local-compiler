Emitter = null
DockerCompose = null
DrayManager = null
BuildpackJob = null
whenjs = null
pipeline = null
semver = null
path = null
glob = null
fs = null

Function::property = (prop, desc) ->
	Object.defineProperty @prototype, prop, desc

module.exports =
	class DockerManager
		constructor: (@timeout=5) ->
			return if @drayManager
			{Emitter} = require 'event-kit'
			{DockerCompose} = require 'docker-compose-tool'
			{DrayManager, BuildpackJob} = require 'dray-client'
			whenjs ?= require 'when'
			pipeline ?= require 'when/pipeline'
			path ?= require 'path'
			glob ?= require 'glob'
			fs ?= require 'fs'

			@emitter = new Emitter
			try
				@compose = new DockerCompose({
					composePath: path.join(__dirname, '..', 'docker-compose.yml'),
					forceRecreate: true
				})

				@initPromise = @compose.up()

				@initPromise.then () =>
					require('dns').lookup require('os').hostname(), (err, addr, fam) =>
						@compose.logs 'dray', @drayLogParser

						@drayManager = new DrayManager(
							"http://#{addr}:12345",
							"redis://#{addr}:6379",
						)
						@initPromise = null
				, (reason) =>
					@handleError reason
			catch error
				@handleError error

		destroy: ->
			@emitter.dispose()

		drayRequired: (callback) ->
			if @initPromise
				atom.notifications.addError 'The compile server is still starting up. Please wait a bit and try again.',
					dismissable: true
				return
			callback()

		drayLogParser: (log) ->
			regex = /msg="(.*)"/
			parsed = regex.exec log
			message = if parsed then parsed[1] else log

			if message.startsWith 'Pulling'
				atom.notifications.addInfo "#{message}...\n\nIt make take a bit longer the first time..."

			if message.startsWith 'API error'
				regex = /API error \((\d+)\)\: (.*)/
				parsed = regex.exec message
				json = JSON.parse parsed[2].replace(/\\"/g, '"').replace('\\n', '')
				atom.notifications.addError "Docker error #{parsed[1]}",
					detail: json.message
					dismissable: true

		compile: (projectDir, outputDir, env, version, platform) -> @drayRequired =>
			# TODO: Catch missing image
			job = new BuildpackJob(@drayManager)

			files = glob.sync projectDir + '/**/*.{c,cpp,h,hpp,ino,properties}'
			files = files.map (file) ->
				{
					name: file.replace("#{projectDir}/", ''),
					data: fs.readFileSync(file)
				}

			job.addFiles(files)
			job.setEnvironment(env)
			job.setBuildpacks([
				'particle/buildpack-wiring-preprocessor',
				'particle/buildpack-install-dependencies',
				"particle/buildpack-particle-firmware:#{version}-#{platform}"
			])
			job.submit().then (binaries) =>
				for k, v of binaries
					fs.writeFileSync path.join(outputDir, k), v
				job.getLogs()

		onError: (callback) ->
			@emitter.on 'error', callback

		handleError: (error) ->
			@emitter.emit 'error', error
