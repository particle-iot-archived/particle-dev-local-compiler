DockerManager = require '../lib/docker-manager'

# TODO: Figure out how to fake Docker API
xdescribe 'Docker Manager', ->
	describe 'Listing images', ->
		it 'lists images', ->
			dockerManager = new DockerManager()
			dockerManager.getVersions().then (versions) ->
				console.log 'getVersions', versions

	describe 'Pulling image', ->
		it 'pulls image', ->
			dockerManager = new DockerManager()
			dockerManager.pull().then ->
				console.log 'pull() finished'
			, (reason) ->
				console.error 'pull() failed because of ', reason

	describe 'Running container', ->
		it 'runs container', ->
			dockerManager = new DockerManager()
			i = '/Users/particle/Projects/Particle/Trunk/Blink'
			o = '/Users/particle/Projects/Particle/Trunk/Blink/build'
			c = '/Users/particle/tmp/cache'
			env =
				PLATFORM_ID: 6
			dockerManager.run(i, o, c, env).then (data, container) ->
				console.log 'run() finished with', data, container
			, (reason) ->
				console.error 'run() failed because of ', reason
