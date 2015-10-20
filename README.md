# Particle Dev Local Compiler

**Note:** local compilation is an experimental feature and may have issues with some projects.

![Particle Dev Local Compiler](http://cl.ly/image/2q040i183M01/Screen%20Recording%202015-10-15%20at%2002.05%20PM.gif)

## Installation steps

### Install Docker Toolbox

First follow instructions for [OS X](https://docs.docker.com/mac/step_one/) / [Windows](https://docs.docker.com/windows/step_one/) / [Linux](https://docs.docker.com/linux/started/).

If everything went well, open **Docker Quickstart Terminal** and type:
```
$ docker-machine env default
```
and take note of values that were shown.

### Install and setup this package

1. Open **Atom** or **Particle Dev**
2. Open **Command Palette** (`Cmd`-`Shift`-`P` on OS X or `Ctrl`-`Shift`-`P` on Windows/Linux)
3. Type *install packages*
4. Choose **Settings View: Install Packages and Themes**
5. Search for *Particle Dev Local Compiler*
6. Install found package
7. Click **Settings** next to package
8. Fill **Docker Cert Path** and **Docker Host** with noted values from `docker-machine` output
9. Open **Command Palette**
10. Type *update firmware*
11. Choose **Particle Dev Local Compiler: Update Firmware Versions**

After this finishes you should be ready to start using local compiler.

## Usage

### Selecting target platform/version
After installation you should see two new items in status bar next to selected device:

![Target platform and target firmware version](http://cl.ly/image/3S3C3u010c0H/dev-target-platform-and-version.png)

First one allows you to select for which platform you want to build the firmware.

Second allows to select which firmware version should be targeted.

**Note:** those currently affect only local compilation.

**Note:** not all platforms are compatible with all versions (i.e. `0.3.4` won't work for Photon).

### Compiling locally

With project opened you should see two icons with check icon on them:

![Flash and compile buttons](http://cl.ly/image/0t3M1g2A3Y1u/dev-compile-locally.png)

First one will do a cloud compile as previously.

Second does a local compilation. Clicking it will create `build` directory in your project and fill it with compilation results.

Resulting binary can be flashed over the air using **Flash** icon on over the wire using `particle flash --usb <filename>` [CLI command](https://docs.particle.io/reference/cli/#particle-flash).
