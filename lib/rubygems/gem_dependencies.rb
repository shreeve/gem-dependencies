# =============================================================================
# gem_dependencies.rb: Simplifies installing binary gems on runtime systems
#
# Author: Steve Shreeve <steve.shreeve@gmail.com>
#   Date: June 12, 2015
#  Legal: MIT License
# =============================================================================

require "yaml"

module Gem
  if ENV["GEM_DEPENDENCIES"]
    pre_install do |gem|
      if gem.spec.extensions.any?
        gem.extend Gem::Installer::Dependencies
      end
    end
  end

  class Installer
    module Dependencies
      require 'rubygems/user_interaction'
      include Gem::UserInteraction

      REGEXP_SCHEMA = %r|\A[a-z][a-z\d]{1,5}://|i
      REGEXP_DEVPKG = %r|^\+|
      REGEXP_DEVARG = %r|^(?=-)|

      def build_extensions
        if deps = find_dependencies(ENV["GEM_DEPENDENCIES"])
          pkgs, exts, args = deps
          install_os_packages(*pkgs) if pkgs.any?
          if args
            @build_args.concat(args)
            super
            path = "#{spec.full_name}.tar.gz"
            File.binwrite(path, gzip(tar(spec.extension_dir)))
            say "Extensions packaged as #{path}"
          end
          copy_gem_extensions(*exts) if exts.any?
        end
        true
      end

      # return a gem's packages, extensions, and arguments
      def find_dependencies(env)
        args = [] if (env = env.dup).sub!(REGEXP_DEVPKG,'') # are we in compile mode?
        return [[], [], args] if args && env.empty?

        require 'rubygems/remote_fetcher'
        @@deps = YAML.load(fetch(env))['gems'] unless defined?(@@deps)
        @@deps.key?(spec.name) or return(args ? [[], [], args] : nil)

        # find dependencies
        case deps = @@deps[spec.name]
        when nil, "*" # for nil or '*', use the default extension name
          deps = ["*"]
        when String # string of space-delimited packages and extensions
        when Array # array of packages and extensions
        when Hash # hash of packages and extensions, indexed by version requirements
          reqs, deps = deps.find do |reqs, info| # deps is an array or space-delimited string
            Gem::Requirement.new(reqs.split(',')).satisfied_by?(spec.version)
          end
          reqs or return # can't find the right version
          deps ||= ["*"] # deps are nil, use the default extension name
        end
        deps = deps.strip.split(/\s+/) if deps.is_a?(String)
        deps = deps.compact.uniq

        # helpful variables
        bcwd = Dir.pwd
        benv = File.dirname(env.split(/[?;#]/,2).first)
        name = "#{spec.full_name}.tar.gz"

        # grok dependencies
        pkgs, exts = [], []
        deps.each do |item|
          if item.include?("*") || item =~ REGEXP_SCHEMA || item.include?(".tar.gz")
            exts << item unless args
          elsif item =~ REGEXP_DEVPKG
            pkgs << $' if args
          elsif item =~ REGEXP_DEVARG
            args << $' if args
          else
            pkgs << item unless args
          end
        end
        exts.map! do |item|
          case item
            when "*"       then item = File.join(benv, name) # use complete default tarball name
            when /\A\*/    then item[0,1] = benv             # path relative to env variable
            when /\A[^\/]/ then item[0,0] = bcwd + "/"       # path relative to current directory
          end
          item.gsub("*", name) # swap inline wildcards with default tarball name
        end
        [pkgs, exts, args]
      end

      def install_os_packages(*args)
        args.each do |item|
          say "* Installing '#{item}'"
        end
        exec = @@deps["*"]["command"].sub('${packages}', args * ' ')
        system(exec) or return warn("Unable to execute: #{exec}")
      end

      def copy_gem_extensions(*args)
        require 'rubygems/remote_fetcher'

        root = spec.extension_dir
        args.each do |item|
          say "* Extracting '#{item}' to '#{root}'"
          untar(gunzip(fetch(item)), root)
        end
        true # success/error?
      end

      def fetch(item)
        tool = Gem::RemoteFetcher.fetcher
        item = item + "?raw=true" if item.start_with?("https://github.com/")
        item =~ REGEXP_SCHEMA ? tool.fetch_path(item) : File.binread(item)
      end

      # The tar/gz code below is based on MIT licensed code by Colin MacKenzie IV

      def tar(dir, ext=nil)
        path = File.expand_path(dir)
        skip = path.size + 1
        tar_io = StringIO.new
        Gem::Package::TarWriter.new(tar_io) do |tar|
          Dir[File.join(path, "**/*#{'.' + ext if ext}")].each do |file|
            stat = File.stat(file)
            name = file[skip..-1]
            if stat.file?
              tar.add_file_simple(name, stat.mode, stat.size) do |tf|
                tf.write(File.binread(file))
              end
            elsif stat.directory?
              tar.mkdir(name, stat.mode)
            end
          end
        end
        tar_io.string
      end

      def gzip(str)
        gz_io = StringIO.new
        z = Zlib::GzipWriter.new(gz_io)
        z.write(str)
        z.close
        gz_io.string
      end

      def gunzip(str)
        return str if str[0,2] != [31,139].pack('C2') # gzip signature
        gz_io = StringIO.new(str)
        z = Zlib::GzipReader.new(gz_io)
        str = z.read
        z.close
        str
      end

      def untar(str, dir)
        tar_io = StringIO.new(str)
        root = File.expand_path(dir)
        Gem::Package::TarReader.new(tar_io) do |tar|
          tar.each do |file|
            path = File.join(root, file.full_name)
            mode = file.header.mode
            if file.directory?
              FileUtils.mkdir_p(path, mode:mode)
            else
              FileUtils.mkdir_p(File.dirname(path))
              File.binwrite(path, file.read)
              FileUtils.chmod(mode, path)
            end
          end
        end
      end
    end
  end
end
