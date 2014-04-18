# Node Version Manager Extended [![Build Status](https://travis-ci.org/bojoer/nvm-extended.svg?branch=master)](https://travis-ci.org/bojoer/nvm-extended)

## Installation

First you'll need to make sure your system has a c++ compiler.  For OSX, XCode will work, for Ubuntu, the build-essential and libssl-dev packages work.

### Install script

To install you could use the [install script](https://github.com/bojoer/nvm-extended/blob/v0.1.0/install.sh) using cURL:

    curl https://raw.github.com/bojoer/nvm-extended/v0.1.0/install.sh | sh

or Wget:

    wget -qO- https://raw.github.com/bojoer/nvm/v0.1.0/install.sh | sh

<sub>The script clones the nvm-extended repository to `~/.nvm-extended` and adds the source line to your profile (`~/.bash_profile`, `~/.zshrc` or `~/.profile`).</sub>

You can customize the install source, directory and profile using the `NVME_SOURCE`, `NVME_DIR` and `NVME_PROFILE` variables. Eg: `curl ... | NVME_DIR=/usr/local/nvme sh` for a global install.

<sub>*NB. The installer can use Git, cURL or Wget to download NVM Extended, whatever is available.*</sub>

### Manual install

For manual install create a folder somewhere in your filesystem with the `nvme.sh` file inside it.  I put mine in a folder called `nvme`.

Or if you have `git` installed, then just clone it:

    git clone https://github.com/bojoer/nvm-extended.git ~/.nvm-extended

To activate nvme, you need to source it from your shell:

    source ~/.nvm-extended/nvme.sh OR . ~/.nvm-extended/nvme.sh

I always add this line to my `~/.bashrc`, `~/.profile`, or `~/.zshrc` file to have it automatically sourced upon login.
Often I also put in a line to use a specific version of node.

## Usage

To download, compile, and install the latest v0.10.x release of node, do this:

    nvme install 0.10

And then in any new shell just use the installed version:

    nvme use 0.10

You can create an `.nvmerc` file containing version number in the project root folder; run the following command to switch versions:

    nvme use

Or you can just run it:

    nvme run 0.10

If you want to see what versions are installed:

    nvme ls

If you want to see what versions are available to install:

    nvme ls-remote

To restore your PATH, you can deactivate it.

    nvme deactivate

To set a default Node version to be used in any new shell, use the alias 'default':

    nvme alias default 0.10

To use a mirror of the node binaries, set `$NVME_NODEJS_ORG_MIRROR`:

    export NVME_NODEJS_ORG_MIRROR=http://nodejs.org/dist
    nvme install 0.10

    NVME_NODEJS_ORG_MIRROR=http://nodejs.org/dist nvme install 0.10

## License

nvme is released under the MIT license.

Copyright (C) 2014-2014 Joeri Boudewijns
Based on Copyright (C) 2010-2014 Tim Caswell

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

## Running tests
Tests are written in [Urchin](https://github.com/scraperwiki/urchin). Install Urchin (and other dependencies) like so:

    npm install

There are slow tests and fast tests. The slow tests do things like install node
and check that the right versions are used. The fast tests fake this to test
things like aliases and uninstalling. From the root of the nvme git repository,
run the fast tests like this.

    npm run test/fast

Run the slow tests like this.

    npm run test/slow

Run all of the tests like this

    npm test

Nota bene: Avoid running nvme while the tests are running.

## Bash completion

To activate, you need to source `bash_completion`:

  	[ -r "$NVME_DIR/bash_completion" ] && . "$NVME_DIR/bash_completion"

Put the above sourcing line just below the sourcing line for NVM Extended in your profile (`.bashrc`, `.bash_profile`).

### Usage

nvme

	$ nvme [tab][tab]
	alias          copy-packages  help           list           run            uninstall      version
	clear-cache    deactivate     install        ls             unalias        use

nvme alias

	$ nvme alias [tab][tab]
	default

	$ nvme alias my_alias [tab][tab]
	v0.4.11        v0.4.12       v0.6.14

nvme use

	$ nvme use [tab][tab]
	my_alias        default        v0.4.11        v0.4.12       v0.6.14

nvme uninstall

	$ nvme uninstall [tab][tab]
	my_alias        default        v0.4.11        v0.4.12       v0.6.14

## Problems

If you try to install a node version and the installation fails, be sure to delete the node downloads from src (~/.nvm-extended/src/) or you might get an error when trying to reinstall them again or you might get an error like the following:

    curl: (33) HTTP server doesn't seem to support byte ranges. Cannot resume.

Where's my 'sudo node'? Checkout this link:

https://github.com/creationix/nvm/issues/43

on Arch Linux and other systems using python3 by default, before running *install* you need to

      export PYTHON=python2

After the v0.8.6 release of Node.js, nvme tries to install from binary packages. But in some systems, the official binary packages don't work due to incompatibility of shared libs. In such cases, use `-s` option to force install from source:

    nvme install -s 0.8.6
