# gem-dependencies

A RubyGems plugin to simplify installing binary gems on runtime systems. Runtime system are usually lightweight and might not even have a compiler. This is accomplished by using a development machine to determine these dependencies and to create tarballs of compiled extensions. Through the use of a dependency index file, these dependencies and extensions can be clearly specified and shared.

## Usage

You don't need to do anything special, just use ```gem install``` as normal. The resulting behavior is controlled by the value of the ```GEM_DEPENDENCIES``` environment variable. If this environment variable is not set, then this gem has no effect and is simply ignored.

## Development system

Make sure you have a development system with the same architecture as your runtime system. On the development system, make a note of all of the package dependencies needed to install the desired gem. Finally, run:

```shell
$ GEM_DEPENDENCIES=1 gem install bcrypt
```

This will perform a normal install, but it will also create a tarball in the current directory with the compiled extensions for the given gem. The naming scheme is straightforward and based on the gem's name and version (e.g. ```bcrypt-3.1.10.tar.gz```).

## Dependency index

The dependency index is a YAML file that contains information necessary to install gems on the runtime system. An example dependency file looks like:

```yaml
gems:
  "*":
    command: sudo apk --update add ${packages}
  bcrypt:
    "~> 2.0, <= 3.3":
      - bcrypt-2.1
      - "*"
  nokogiri:
    "~> 1.6.2, < 1.8": "* libxml2-dev libxslt-dev"
    "1.2.8": "s3://one:two@s3.amazon.com/three/* tree"
```

After determining the runtime dependencies and creating a compiled extensions tarball, edit the dependency index to add a key with the name of the new gem and sub-keys to indicate the version requirements. The values of these sub-key are either an array of package dependencies and extension tarballs or a space-delimited string of the same. All items ending in ```.tar.gz``` are considered to be extension tarballs and everything else is considered to be a package dependency. Extension tarballs can also be given as a file system path or an http, https, git, or s3 url.

## Runtime system

If ```GEM_DEPENDENCIES``` is set to a file system path or an http, https, git, or s3 url, then this value will be used to fetch the dependency index. Suppose the following command is run from the runtime system:

```shell
export GEM_DEPENDENCIES="https://github.com/shreeve/gemdeps-alpine-3.2-x86_64-2.2.0/blob/master/INDEX.yaml"
gem install bcrypt
```

The dependency index will be downloaded and searched for the requested gem and version. If a match is found, then the order of installation is as follows:

* package dependencies will be installed (uses the value from the ```command``` key),
* the 'normal' gem files will be installed
* the 'normal' build_extensions step will be skipped, and
* compiled extension tarballs will be downloaded and installed

Note that a version requirement can also be specified in the ```gem install``` command. For example, the following are all valid:

```shell
gem install bcrypt
gem install bcrypt:3.1.4
gem install "bcrypt:~>3.1.8"
gem install "bcrypt > 3.1.4, ~> 3.2, < 3.8"
```

Using this approach, a runtime system can quickly and efficiently install dependencies and extensions without the need to compile them locally.

## Using bundler

To make bundler to use this gem as well, you need to load the rubygems_plugin before. The easiest way is to make an alias in your `~/.bashrc`, such as:

```
alias bundle='RUBYOPT="-rrubygems/gem_dependencies" bundle'
```

## Todos

* Allow both compiler and runtime package dependencies in the dependency index file
* Allow the use of flags (such as ```--use-system-libraries```) for packages
* ~~Make sure everything works seamlessly with ```bundler```~~
* Document the various formats supported in the dependency index file
* Document how to create a platform repository (e.g. on GitHub)

## License

This software is licensed under terms of the MIT License.
