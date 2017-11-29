'use babel';

import whenjs from 'when';
let fs = null;
let glob = null;
let path = null;
let os = null;
let CompositeDisposable = null;
let DockerManager = null;

export default {
	packageName: 'particle-dev-local-compiler',
	subscriptions: null,
	loaded: false,
	statusBarDefer: whenjs.defer(),
	consolePanelDefer: whenjs.defer(),
	consoleToolBar: whenjs.defer(),
	coreDefer: whenjs.defer(),
	profilesDefer: whenjs.defer(),

	activate(state) {
		({CompositeDisposable} = require('atom'));
		if (DockerManager == null) { DockerManager = require('./docker-manager'); }
		if (fs == null) { fs = require('fs-plus'); }
		if (glob == null) { glob = require('glob'); }
		if (path == null) { path = require('path'); }

		// Install packages we depend on
		require('atom-package-deps').install('particle-dev-local-compiler', true);

		this.subscriptions = new CompositeDisposable;

		this.setupDocker();

		this.activatePromise = whenjs.all([
			this.statusBarDefer.promise,
			this.consolePanelDefer.promise,
			this.consoleToolBar.promise,
			this.coreDefer.promise,
			this.profilesDefer.promise
		]);

		return this.setupCommands();
	},

	deactivate() {
		return this.subscriptions.dispose();
	},

	serialize() {},

	consumeStatusBar(statusBar) {
		this.statusBar = statusBar;
		return this.statusBarDefer.resolve(this.statusBar);
	},

	consumeConsolePanel(consolePanel) {
		this.consolePanel = consolePanel;
		return this.consolePanelDefer.resolve(this.consolePanel);
	},

	consumeToolBar(toolBar) {
		this.toolBar = toolBar(this.packageName);
		this.toolBarButton = this.toolBar.addButton({
			icon: 'checkmark-circled',
			callback: this.packageName + ':compile-locally',
			tooltip: 'Compile locally',
			iconset: 'ion',
			priority: 521
		});
		return this.consoleToolBar.resolve(this.toolBar);
	},

	consumeParticleDev(core) {
		this.core = core;
		return this.coreDefer.resolve(this.core);
	},

	consumeProfiles(profileManager) {
		this.profileManager = profileManager;
		return this.profilesDefer.resolve(this.profileManager);
	},

	config: {
		outputDirectory: {
			type: 'string',
			default: 'build',
			description: 'Directory name which will be appended to project directory. Contains logs and other build artefacts.'
		},

		cacheDirectory: {
			type: 'string',
			default: '~/.particledev/cache',
			description: 'Directory holding intermediate files between builds.'
		},

		defaultTimeout: {
			type: 'number',
			default: 20,
			description: 'Default compile timeout'
		},

		logDray: {
			type: 'boolean',
			default: false,
			description: 'Log debug information from Dray'
		}
	},

	dockerManagerRequired() {
		return new Promise((resolve, reject) => {
			if (!this.dockerManager) {
				this.setupDocker();
				reject();
			}
			resolve();
		})
	},

	setupDocker() {
		if (os == null) { os = require('os'); }
		// Fix for "Unable to connect to Docker" error
		if (os.type() === "Darwin") {
			const childProcess = require('child_process');
			process.env.PATH = childProcess.execFileSync(process.env.SHELL, ['-i', '-c', 'echo $PATH']).toString().trim();
		}

		this.dockerManager = null;

		this.dockerManager = new DockerManager(
			atom.config.get(this.packageName + '.defaultTimeout'),
			atom.config.get(this.packageName + '.logDray')
		);
		this.dockerManager.onError(error => {
			if ((typeof error !== 'string') && (!['ETIMEDOUT', 'ECONNREFUSED'].includes(error.errno))) {
				error = error.toString();
				return atom.notifications.addError(error,
					{dismissable: true});
			} else {
				let notification;
				console.error(error);
				error = `Unable to connect to Docker.\n
Check if Docker is running (you can use \`docker ps -a\` in command line).\n
Reason:
\`\`\`${error}\`\`\`\
`;
				return notification = atom.notifications.addError(error,
					{dismissable: true});
			}
		});

		return true;
	},

	setupCommands() {
		return this.addCommand('compile-locally', () => this.compile());
	},

	ensureOutputDir(projectDir) {
		const outputDir = path.join(projectDir, atom.config.get(this.packageName + '.outputDirectory'));
		fs.makeTreeSync(outputDir);
		const filesToRemove = glob.sync(outputDir + '/*.{log,bin}');
		for (let file of filesToRemove) {
			fs.removeSync(file);
		}
		return outputDir;
	},

	setToolBarButtonProgress(inProgress) {
		if (inProgress) {
			this.toolBarButton.element.classList.add('ion-looping');
		} else {
			this.toolBarButton.element.classList.remove('ion-looping');
		}
	},

	compile() {
		Promise.resolve().then(() => {
			return this.activatePromise;
		}).then(() => {
			return this.dockerManagerRequired();
		}).then(() => {
			return new Promise((resolve, reject) => this.core.projectRequired(resolve));
		}).then(() => {
			const projectDir = this.core.getProjectDir();

			const outputDir = this.ensureOutputDir(projectDir);
			const currentBuildTarget = this.profileManager.getLocal('current-build-target');
			const currentPlatform = this.profileManager.currentTargetPlatformName.toLowerCase();
			this.consolePanel.clear();
			this.setToolBarButtonProgress(true);
			// TODO: Remove old files from output dir

			const promise = this.dockerManager.compile(projectDir, outputDir, {
					PLATFORM_ID: this.profileManager.currentTargetPlatform,
					ACCESS_TOKEN: this.profileManager.get('access_token')
				},
				currentBuildTarget,
				currentPlatform);

			return promise.then(result => {
				const memoryUseFile = path.join(outputDir, 'memory-use.log');
				if (fs.existsSync(memoryUseFile)) {
					this.consolePanel.raw(fs.readFileSync(memoryUseFile).toString());
				}

				// Rename binary based on platform
				const outputFile = path.join(projectDir,
					`${currentPlatform}_${currentBuildTarget}_firmware_` + (new Date()).getTime() + '.bin');
				fs.moveSync(path.join(outputDir, 'firmware.bin'), outputFile);

				this.setToolBarButtonProgress(false);
			}
			, error => {
				this.setToolBarButtonProgress(false);
				if (Array.isArray(error)) {
					for (let line of error) {
						this.consolePanel.error(line);
					}

					this.consolePanel.error('Local compilation failed');
				} else {
					atom.notifications.addError(error);
				}
			});
		});
	},

	addCommand(name, callback, target) {
		if (target == null) { target = 'atom-workspace'; }
		name = this.packageName + ':' + name;
		return this.subscriptions.add(atom.commands.add(target, name, callback));
	}
};
