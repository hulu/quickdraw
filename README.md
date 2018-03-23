# Quickdraw
A Hulu Original Binding Library

## Purpose
Inspired by Knockout.js, Quickdraw is meant to bridge the gap between MVVM and the living room experience. Optimized for low powered devices, Quickdraw brings the power of observable bindings along with the speed necessary for a fluid living room experience.

# Developing
Quickdraw leverages Node.js and Gulp to make development nice and simple. The following information assumes that you have Node.js and npm already installed on your system.

## Installing the Dependencies
The following commands, run in the cloned repository folder should get you up and running
```
# Install gulp globally
npm install -g gulp
# Install the development dependencies of Quickdraw
npm install
```
## Gulp Commands
### `gulp clean`
This will delete any built and generated files that have been created by other gulp commands

### `gulp compile`
This will compile the base Quickdraw source and all the provided handlers into a singular `quickdraw.js` file

### `gulp compile:coverage`
This will create the same `quickdraw.js` file that the `gulp compile` command but it will have line coverage tracking added to it

### `gulp test`
This will run all the tests defined in the `test` directory against the Quickdraw library

### `gulp test:coverage`
This will run all the tests defined in the `test` directory against the Quickdraw library and produce a set of coverage reports (XUNIT and LCOV) about the library.

### `gulp coverage`
This will run the `gulp test:coverage` command and then take the
output coverage reports and use the systems 'genhtml' command to
produce a browsable HTML page displaying coverage information per file.

### `gulp release`
The release command will build the library, run the test suite, and if all tests pass will up the version found in package.json and finally publish the library to npm. By default it will increment the patch
portion of the version number but you can append 'major', 'minor', or 'patch' to the command (ex `gulp release:major`) to force a different release type.

### `gulp`
The default action is to clean the source directory and compile the library again.
