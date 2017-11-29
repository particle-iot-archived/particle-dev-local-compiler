'use babel';

let Emitter = null;
let DockerCompose = null;
let DrayManager = null;
let BuildpackJob = null;
let whenjs = null;
let pipeline = null;
const semver = null;
let path = null;
let glob = null;
let fs = null;
let stripAnsi = null;

Function.prototype.property = function(prop, desc) {
	return Object.defineProperty(this.prototype, prop, desc);
};

export default class DockerManager {
	constructor(timeout, logDray) {
		if (this.drayManager) { return; }

		if (timeout == null) { timeout = 5; }
		this.timeout = timeout;
		if (logDray == null) { logDray = false; }
		this.logDray = logDray;

		({Emitter} = require('event-kit'));
		({DockerCompose} = require('docker-compose-tool'));
		({DrayManager, BuildpackJob} = require('dray-client'));
		if (whenjs == null) { whenjs = require('when'); }
		if (pipeline == null) { pipeline = require('when/pipeline'); }
		if (path == null) { path = require('path'); }
		if (glob == null) { glob = require('glob'); }
		if (fs == null) { fs = require('fs'); }

		this.emitter = new Emitter;
		try {
			this.compose = new DockerCompose({
				composePath: path.join(__dirname, '..', 'docker-compose.yml'),
				forceRecreate: true
			});

			this.initPromise = this.compose.up();

			this.initPromise.then(() => {
				return require('dns').lookup(require('os').hostname(), (err, addr, fam) => {
					this.compose.logs('dray', this.drayLogParser);

					this.drayManager = new DrayManager(
						`http://${addr}:12345`,
						`redis://${addr}:6379`
					);
					this.initPromise = null;
				});
			}
			, reason => {
				return this.handleError(reason);
			});

			if (this.logDray) {
				if (stripAnsi == null) { stripAnsi = require('strip-ansi'); }
				this.compose.logs('dray', line => {
					console.info(stripAnsi(line));
				});
			}
		} catch (error) {
			this.handleError(error);
		}
	}

	destroy() {
		return this.emitter.dispose();
	}

	drayLogParser(log) {
		let regex = /msg="(.*)"/;
		let parsed = regex.exec(log);
		const message = parsed ? parsed[1] : log;

		if (message.startsWith('Pulling')) {
			atom.notifications.addInfo(`${message}...\n\nIt make take a bit longer the first time...`);
		}

		if (message.startsWith('API error')) {
			regex = /API error \((\d+)\)\: (.*)/;
			parsed = regex.exec(message);
			const json = JSON.parse(parsed[2].replace(/\\"/g, '"').replace('\\n', ''));
			return atom.notifications.addError(`Docker error ${parsed[1]}`, {
				detail: json.message,
				dismissable: true
			});
		}
	}

	compile(projectDir, outputDir, env, version, platform) {
		if (this.initPromise) {
			return Promise.reject('The compile server is still starting up. Please wait a bit and try again.');
		}
		// TODO: Catch missing image
		const job = new BuildpackJob(this.drayManager);

		let files = glob.sync(projectDir + '/**/*.{c,cpp,h,hpp,ino,properties}');
		files = files.map(file =>
			({
				name: file.replace(`${projectDir}/`, ''),
				data: fs.readFileSync(file)
			}));

		job.addFiles(files);
		job.setEnvironment(env);
		job.setBuildpacks([
			'particle/buildpack-wiring-preprocessor',
			'particle/buildpack-install-dependencies',
			`particle/buildpack-particle-firmware:${version}-${platform}`
		]);
		return job.submit().then(binaries => {
			// Hack to catch failed compile somehow still being resolved
			if (binaries == null) {
				return job.getLogs().then((logs) => Promise.reject(logs));
			}

			for (let k in binaries) {
				const v = binaries[k];
				fs.writeFileSync(path.join(outputDir, k), v);
			}
			return job.getLogs();
		});
	}

	onError(callback) {
		return this.emitter.on('error', callback);
	}

	handleError(error) {
		return this.emitter.emit('error', error);
	}
};
