# Particle Dev Local Compiler

**Note:** local compilation is an experimental feature and may have issues with some projects.

![Particle Dev Local Compiler](http://cl.ly/image/2q040i183M01/Screen%20Recording%202015-10-15%20at%2002.05%20PM.gif)

## Installation steps

### Install Docker for your operating system

* [OS X](https://docs.docker.com/docker-for-mac/install/)
* [Windows 64 bit](https://docs.docker.com/docker-for-windows/install/) (unfortunately Docker for Windows isn't available for 32 bit Windows)
* [Linux](https://docs.docker.com/engine/installation/).

## Usage

### Selecting target platform/version

Local compiler uses the same platform/firmware version selectors as [the cloud compile](https://docs.particle.io/guide/tools-and-features/dev/#targeting-different-platforms-and-firmware-versions).

**Note:** currently only Particle devices are supported. Namely: Core, Photon, P1 and Electron.

**Note:** not all platforms/versions might work. We recommend using the latest ones.

### Compiling locally

With project opened you should see two icons with check icon on them:

![Flash and compile buttons](http://cl.ly/image/0t3M1g2A3Y1u/dev-compile-locally.png)

First one will do a cloud compile as previously.

Second does a local compilation. Clicking it will create `build` directory in your project and fill it with compilation results.

Resulting binary can be flashed over the air using **Flash** icon or over the wire using `particle flash --usb <filename>` [CLI command](https://docs.particle.io/reference/cli/#particle-flash).
