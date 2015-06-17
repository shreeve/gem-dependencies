# gem-dependencies

A RubyGems plugin that simplifies working with gems that have binary extensions. It does this through the use of a succinct dependency index file. For development systems, this file specifies build dependencies and arguments necessary to compile and create a tarball with a gem's binary extensions. For runtime systems, which are lightweight and might not have access to a compiler, the dependency index file provides a list of runtime dependencies that must first be installed and also specifies the tarball which contains the pre-built binary extension files.

## TL;DR

Think of ```gem-dependencies``` as a helper that allows lightweight systems, such as docker containers, to be able to use native rubygems without having a compiler installed. At the moment that ```gem install``` would normally try to compile a binary extension, ```gem-dependencies``` will lookup the gem in it's dependency index and, if a matching version is found, install any required runtime packages and then download and extract any pre-compiled binary extensions. Everything works seamlessly and efficiently.

## Usage

You don't need to do anything special, just use ```gem install``` as normal. The resulting behavior is controlled by the value of the ```GEM_DEPENDENCIES``` environment variable. If this environment variable is not set, then this gem has no effect and is simply ignored. If ```GEM_DEPENDENCIES``` is set to a file system path or an http, https, git, or s3 url, then this value will be used to fetch the dependency index. As an additional help, all urls that begin with ```https://github.com/``` will be automatically suffixed with ```?raw=true```.

## Dependency index

The dependency index is a YAML file that contains information necessary to compile gems on a development system or install them on a runtime system. A dependency index file looks like this:

```yaml
gems:
  "*":
    command: apk --update add ${packages}
  bcrypt:
  mysql2: "* mariadb-libs"
  nokogiri: "* libxml2 libxslt +libxml2-dev +libxslt-dev -- --use-system-libraries"
  pokogiri:
    - "*"
    - libxml2
    - libxslt
    - +libxml2-dev
    - +libxslt-dev
    - --
    - --use-system-libraries
  unf_ext:
    "~> 0.0.7.1": "* libstdc++"
    ">= 0.0.4, < 0.0.7": "*/old-gems/* libstdc++"
    "< 0.0.4": "s3://foo:bar@s3.amazon.com/baz/* one two three"
```

The format of this file is quite flexible.  Keys in the above hash represent gems that have binary extensions. The hash values can be ```nil``` (see ```bcrypt```), a ```String``` (see ```mysql2```), an ```Array``` (see ```pokogiri```), or a version-indexed ```Hash``` (see ```unf_ext```). Shortcuts are defined for each space-delimited ```String``` or ```Array``` element such that:

* a ```nil``` or ```*``` is a sibling file to the dependency index, named ```${gemname}-${version}.tar.gz```
* a leading ```*``` will be replaced with the base directory of the dependency index
* a subsequent ```*``` will be replaced with ```${gemname}-${version}.tar.gz```
* a leading ```+``` indicates a development dependency
* a leading ```-``` indicates a build-time argument to the ```gem``` command
* a value containing ```.tar.gz``` indicates a binary extensions tarball

Wildcards can be combined such as ```unf_ext``` where the values for one version range includes ```*/old-gems/*```. In this example, this gives ```https://github.com/shreeve/gemdeps-alpine-3.2-x86_64-2.2.0/blob/master/old-gems/unf_ext-0.0.6.tar.gz```. These shortcuts are much easier to type and they will dynamically use the proper gem versions.

## Development system

Make sure your development system has the same architecture as your runtime system. Development systems are indicated by a leading ```+``` in the value of the ```GEM_DEPENDENCIES``` environment variable. Suppose the following variable is set:

```shell
export GEM_DEPENDENCIES="+https://github.com/shreeve/gemdeps-alpine-3.2-x86_64-2.2.0/blob/master/INDEX.yaml"
```

Then, this command:

```shell
gem install nokogiri
```

will lookup the dependency index, finding:

```yaml
nokogiri: "* libxml2 libxslt +libxml2-dev +libxslt-dev -- --use-system-libraries"
```

which will:

* Install the ```libxml2-dev``` and ```libxslt-dev``` packages (these start with ```+```)
* Execute ```gem install nokogiri -- --use-system-libraries``` (these start with ```-```)
* Create a binary extensions tarball (e.g. ```nokogiri-1.6.6.2.tar.gz```) in the current directory

## Runtime system

Suppose the following variable is set (without the leading ```+``` character):

```shell
export GEM_DEPENDENCIES="https://github.com/shreeve/gemdeps-alpine-3.2-x86_64-2.2.0/blob/master/INDEX.yaml"
```

Then, this command:

```shell
gem install nokogiri
```

will lookup the dependency index, finding:

```yaml
nokogiri: "* libxml2 libxslt +libxml2-dev +libxslt-dev -- --use-system-libraries"
```

which will:

* Install the ```libxml2``` and ```libxslt``` packages
* Execute ```gem install nokogiri```, but will skip the ```build_extensions``` step
* Download and extract the default extensions tarball at ```https://github.com/shreeve/gemdeps-alpine-3.2-x86_64-2.2.0/blob/master/nokogiri-1.6.6.2.tar.gz```

Note that a version requirement can also be specified in the ```gem install``` command. For example, the following are all valid:

```shell
gem install bcrypt
gem install bcrypt:3.1.4
gem install "bcrypt:~>3.1.8"
gem install "bcrypt > 3.1.4, ~> 3.2, < 3.8"
```

Using this approach, a runtime system can quickly and efficiently install dependencies and extensions without the need to compile them locally.

## Using bundler

To make bundler to use this gem as well, you need to require the plugin before ```bundler``` runs. The easiest way is to make an alias in your `~/.bashrc`, such as:

```
alias bundle='RUBYOPT="-rrubygems/gem_dependencies" bundle'
```

Alternatively, you can also just set the environment variable beforehand like this:

```
RUBYOPT="-rrubygems/gem_dependencies" bundle
```

## Docker example with Alpine Linux

### Development system

```shell
# create a new ephemeral container based on the latest alpine linux
docker run -it --rm alpine /bin/sh

# install some baseline packages
apk --update add openssh ca-certificates

# install ruby and setup rubygems to not generate documentation
apk --update add ruby ruby-irb ruby-bigdecimal
echo "gem: --no-document" > /etc/gemrc

# install the alpine sdk and ruby development dependencies
apk --update add alpine-sdk ruby-dev

# install gem-dependencies (use "+" for development systems)
export GEM_DEPENDENCIES="+https://github.com/shreeve/gemdeps-alpine-3.2-x86_64-2.2.0/blob/master/INDEX.yaml"
gem install gem-dependencies

# update rubygems and any installed gems
gem update --system
gem update

# install some gems with binary extensions
mkdir /tmp/gems && cd /tmp/gems
gem install atomic bcrypt

# use bundler (needs io-console)
gem install bundler io-console
alias bundle='RUBYOPT="-rrubygems/gem_dependencies" bundle'
bundle
```

As the development system installs gems, any compiled extensions will be saved as tarballs in the current directory. If a particular gem requires a development package to be installed, make sure to update the dependency index file so those dependencies will be automatically installed for you next time. Also, update the dependency index file to reference the extension tarball and any runtime dependencies.

### Runtime system

```shell
# create a new ephemeral container based on the latest alpine linux
docker run -it --rm alpine /bin/sh

# install some baseline packages
apk --update add openssh ca-certificates

# install ruby and setup rubygems to not generate documentation
apk --update add ruby ruby-irb ruby-bigdecimal
echo "gem: --no-document" > /etc/gemrc

# install gem-dependencies (no "+" means this is a runtime system)
export GEM_DEPENDENCIES="https://github.com/shreeve/gemdeps-alpine-3.2-x86_64-2.2.0/blob/master/INDEX.yaml"
gem install gem-dependencies

# update rubygems and any installed gems
gem update --system
gem update

# install some gems with binary extensions (will download, not compile them)
mkdir /tmp/gems && cd /tmp/gems
gem install atomic bcrypt

# use bundler (needs io-console)
gem install bundler io-console
alias bundle='RUBYOPT="-rrubygems/gem_dependencies" bundle'
bundle
```

The runtime system will refer to the dependency index file to determine which gems require runtime packages and will automatically download and extract and tarballs with compiled extensions.

### Platform repository

A platform repository is simply a location (a file system path or an http, https, git, or s3 url) that contains a dependency index file and, optionally, tarballs with compiled extensions. Ideally, the system's distribution name and version, architecture, and Ruby API level should be included. For an example, please refer to:

* https://github.com/shreeve/gemdeps-alpine-3.2-x86_64-2.2.0

## Todos

* ~~Make sure everything works seamlessly with ```bundler```~~
* ~~Document the various formats supported in the dependency index file~~
* ~~Allow both compiler and runtime package dependencies in the dependency index file~~
* ~~Allow the use of flags (such as ```--use-system-libraries```) for packages~~
* ~~Document how to create a platform repository (e.g. on GitHub)~~

## License

This software is licensed under terms of the MIT License.
