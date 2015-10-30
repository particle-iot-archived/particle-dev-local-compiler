Emitter = null
Docker = null
whenjs = null
pipeline = null
semver = null

Function::property = (prop, desc) ->
	Object.defineProperty @prototype, prop, desc

module.exports =
	class DockerManager
		constructor: (@host, @certPath, @tlsVerify=1, @machineName='default', @timeout=5) ->
			{Emitter} = require 'event-kit'
			Docker ?= require 'dockerode'
			whenjs ?= require 'when'
			pipeline ?= require 'when/pipeline'
			semver ?= require 'semver'

			process.env.DOCKER_TLS_VERIFY = @tlsVerify
			process.env.DOCKER_HOST = @host
			process.env.DOCKER_CERT_PATH = @certPath
			process.env.DOCKER_MACHINE_NAME = @machineName

			@emitter = new Emitter
			try
				@docker = new Docker()
			catch error
				@handleError error


			@imageName = 'particle/buildpack-particle-firmware'

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

		getSemVerVersions: ->
			pipeline [
				=>
					@getVersions()
				(versions) =>
					validVersions = versions.filter semver.valid
					validVersions = validVersions.sort semver.compare
					validVersions.reverse()
			]

		getLatestSemVerVersion: ->
			pipeline [
				=>
					@getSemVerVersions()
				(versions) =>
					versions[0]
			]

		pull: ->
			dfd = whenjs.defer()
			@docker.pull @imageName, (error, stream) =>
				if error
					@handleError error
					dfd.reject error
				else
					stream.on 'data', (data) ->
						console.debug '-->', data.toString()
					stream.on 'end', ->
						console.debug 'Pulling done'
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
				, @timeout * 1000

			dfd.promise

		onError: (callback) ->
			@emitter.on 'error', callback

		handleError: (error) ->
			if error.errno in ['ETIMEDOUT', 'ECONNREFUSED']
				# TODO: Check the link
				error = """Unable to connect to Docker.\n
				Check if your Docker machine is running and [verify Particle Dev Local Compiler package settings are correct](atom://config/packages/particle-dev-local-compiler).
				"""
			if typeof error != 'string'
				error = error.toString()
			@emitter.emit 'error', error
