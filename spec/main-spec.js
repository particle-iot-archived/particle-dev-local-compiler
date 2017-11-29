'use babel';

import ParticleDevLocalCompiler from '../lib/main';

// Use the command `window:run-package-specs` (cmd-alt-ctrl-p) to run specs.
//
// To run a specific `it` or `describe` block add an `f` to the front (e.g. `fit`
// or `fdescribe`). Remove the `f` to unfocus the block.

xdescribe("ParticleDevLocalCompiler", function() {
	let [workspaceElement, activationPromise] = Array.from([]);

	beforeEach(function() {
		workspaceElement = atom.views.getView(atom.workspace);
		return activationPromise = atom.packages.activatePackage('particle-dev-local-compiler');
	});

	return describe("when the particle-dev-local-compiler:toggle event is triggered", function() {
		it("hides and shows the modal panel", function() {
			// Before the activation event the view is not on the DOM, and no panel
			// has been created
			expect(workspaceElement.querySelector('.particle-dev-local-compiler')).not.toExist();

			// This is an activation event, triggering it will cause the package to be
			// activated.
			atom.commands.dispatch(workspaceElement, 'particle-dev-local-compiler:toggle');

			waitsForPromise(() => activationPromise);

			return runs(function() {
				expect(workspaceElement.querySelector('.particle-dev-local-compiler')).toExist();

				const particleDevLocalCompilerElement = workspaceElement.querySelector('.particle-dev-local-compiler');
				expect(particleDevLocalCompilerElement).toExist();

				const particleDevLocalCompilerPanel = atom.workspace.panelForItem(particleDevLocalCompilerElement);
				expect(particleDevLocalCompilerPanel.isVisible()).toBe(true);
				atom.commands.dispatch(workspaceElement, 'particle-dev-local-compiler:toggle');
				return expect(particleDevLocalCompilerPanel.isVisible()).toBe(false);
			});
		});

		return it("hides and shows the view", function() {
			// This test shows you an integration test testing at the view level.

			// Attaching the workspaceElement to the DOM is required to allow the
			// `toBeVisible()` matchers to work. Anything testing visibility or focus
			// requires that the workspaceElement is on the DOM. Tests that attach the
			// workspaceElement to the DOM are generally slower than those off DOM.
			jasmine.attachToDOM(workspaceElement);

			expect(workspaceElement.querySelector('.particle-dev-local-compiler')).not.toExist();

			// This is an activation event, triggering it causes the package to be
			// activated.
			atom.commands.dispatch(workspaceElement, 'particle-dev-local-compiler:toggle');

			waitsForPromise(() => activationPromise);

			return runs(function() {
				// Now we can test for view visibility
				const particleDevLocalCompilerElement = workspaceElement.querySelector('.particle-dev-local-compiler');
				expect(particleDevLocalCompilerElement).toBeVisible();
				atom.commands.dispatch(workspaceElement, 'particle-dev-local-compiler:toggle');
				return expect(particleDevLocalCompilerElement).not.toBeVisible();
			});
		});
	});
});
