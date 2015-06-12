#!/usr/bin/env ruby

# =============================================================================
# gem_dependencies.rb: Simplifies installing binary gems on runtime systems
#
# Author: Steve Shreeve <steve.shreeve@gmail.com>
#   Date: June 11, 2015
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
      REGEXP_SCHEMA = %r|\A[a-z][a-z\d]{1,5}://|io

      def build_extensions
        if (env = ENV["GEM_DEPENDENCIES"]) == "1"
          super
          path = "#{spec.full_name}.tar.gz"
          File.binwrite(path, gzip(tar(spec.extension_dir)))
          say "Extensions packaged as #{path}"
        elsif deps = find_dependencies(env)
          pkgs, exts = deps
          install_os_packages(*pkgs) if pkgs.any?
          copy_gem_extensions(*exts) if exts.any?
        end
        true
      end

      # locate a match and return [pkgs, exts]
      def find_dependencies(env)
        require 'rubygems/remote_fetcher'
        @@deps = YAML.load(fetch(env))['gems'] unless defined?(@@deps)

        case deps = @@deps[spec.name]
        when String
        when Array
        when Hash
          reqs, deps = deps.find do |reqs, info|
            Gem::Requirement.new(reqs.split(',')).satisfied_by?(spec.version)
          end
        end
        deps or return
        deps = deps.strip.split(/\s+/) if deps.is_a?(String)
        deps.compact.uniq.partition {|item| item =~ REGEXP_SCHEMA || item.end_with?(".tar.gz")}.reverse
      end

      def install_os_packages(*args)
        args.each do |item|
          say "* Installing '#{item}' dependency"
        end
        cmds = @@deps["*"]["command"].strip.split(/\s+/).flat_map {|item| item == '${packages}' ? args : item}
        Gem::Util.silent_system(*cmds)
        true # success/error?
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
              FileUtils.mkdir_p(path, mode)
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
