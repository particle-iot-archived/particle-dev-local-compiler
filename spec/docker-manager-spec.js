'use babel';

import DockerManager from '../lib/docker-manager';

// TODO: Figure out how to fake Docker API
xdescribe('Docker Manager', function() {
	describe('Listing images', () =>
		it('lists images', function() {
			const dockerManager = new DockerManager();
			return dockerManager.getVersions().then(versions => console.log('getVersions', versions));
		})
	);

	describe('Pulling image', () =>
		it('pulls image', function() {
			const dockerManager = new DockerManager();
			return dockerManager.pull().then(() => console.log('pull() finished')
			, reason => console.error('pull() failed because of ', reason));
		})
	);

	return describe('Running container', () =>
		it('runs container', function() {
			const dockerManager = new DockerManager();
			const i = '/Users/particle/Projects/Particle/Trunk/Blink';
			const o = '/Users/particle/Projects/Particle/Trunk/Blink/build';
			const c = '/Users/particle/tmp/cache';
			const env =
				{PLATFORM_ID: 6};
			return dockerManager.run(i, o, c, env).then((data, container) => console.log('run() finished with', data, container)
			, reason => console.error('run() failed because of ', reason));
		})
	);
});
