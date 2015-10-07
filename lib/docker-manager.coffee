Emitter = null
Docker = null
whenjs = null

Function::property = (prop, desc) ->
	Object.defineProperty @prototype, prop, desc

module.exports =
	class DockerManager
		constructor: (@host, @certPath, @tlsVerify=1, @machineName='default') ->
			{Emitter} = require 'event-kit'
			Docker = require 'dockerode'
			whenjs = require 'when'

			# TODO: Move this to settings
			process.env.DOCKER_TLS_VERIFY = @tlsVerify
			process.env.DOCKER_HOST="tcp://192.168.99.100:2376"
			process.env.DOCKER_CERT_PATH="/Volumes/128GB/VirtualBox/docker-machine/machines/default"
			process.env.DOCKER_MACHINE_NAME = @machineName

			@emitter = new Emitter
			@docker = new Docker()

			@imageName = 'particle/buildpack-particle-firmware'
			@timeout = 5000

		destroy: ->
			@emitter.dispose()

		getVersions: ->
			dfd = whenjs.defer()
			@docker.listImages (error, data) =>
				if error
					@handleError error
					dfd.reject error
				else
					versions = []
					for image in data
						if image.RepoTags.length
							if image.RepoTags[0].startsWith(@imageName + ':')
								versions.push image.RepoTags[0].split(':')[1]

					dfd.resolve versions
			dfd.promise

		pull: ->
			dfd = whenjs.defer()
			@docker.pull @imageName, (error, stream) =>
				if error
					@handleError error
					dfd.reject error
				else
					dfd.resolve()
			dfd.promise

		run: (inputDir, outputDir, cacheDir, env=[], version='latest') ->
			dfd = whenjs.defer()
			killed = false
			env = (key + '=' + variable for key, variable of env)
			createOptions =
				Env: env

			startOptions =
				HostConfig:
					Binds: [
						inputDir + ':/input',
						outputDir + ':/output',
						cacheDir + ':/cache'
					]
				Volumes:
					'/input': {},
					'/output': {},
					'/cache': {}

			hub = @docker.run @imageName + ':' + version, [], null, createOptions, startOptions, (error, data, container) =>
				if error
					@handleError error
					dfd.reject error
				else
					clearTimeout @timer
					if killed
						return
					dfd.resolve data, container

			hub.on 'container', (container) =>
				# Stop long running containers
				@timer = setTimeout =>
					killed = true
					container.kill (error, data) =>
						if !error
							error = 'Compilation timed out'
						dfd.reject error
						@handleError error
				, @timeout

			dfd.promise

		onError: (callback) ->
			@emitter.on 'error', callback

		handleError: (error) ->
			@emitter.emit 'error', error
