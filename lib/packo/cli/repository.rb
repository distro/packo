# encoding: utf-8
#--
# Copyleft meh. [http://meh.doesntexist.org | meh@paranoici.org]
#
# This file is part of packo.
#
# packo is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# packo is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with packo. If not, see <http://www.gnu.org/licenses/>.
#++

require 'open-uri'
require 'nokogiri'

require 'packo'
require 'packo/rbuild'
require 'packo/models'
require 'packo/cli/repository/helpers'

module Packo; module CLI

class Repository < Thor
  include Thor::Actions

  @@scm = ['git']

  class_option :help, :type => :boolean, :desc => 'Show help usage'

  desc 'add URI...', 'Add repositories'
  map '-a' => :add
  def add (*uris)
    uris.each {|uri|
      uri  = URI.parse(uri)
      kind = nil
      type = nil
      name = nil

      if uri.scheme.nil? || uri.scheme == 'file'
        kind = :file

        if uri.to_s.end_with?('.rb')
          uri = File.realpath(uri.path)

          type = :virtual
          name = File.basename(uri.to_s).sub('.rb', '')
        else
          if File.directory? uri.path
            dom = Nokogiri::XML.parse(File.read("#{uri.path}/repository.xml"))
          else
            dom = Nokogiri::XML.parse(File.read(uri.path))
          end

          uri = File.realpath(uri.path)

          type = dom.root['type'].to_sym
          name = dom.root['name']
        end
      elsif ['http', 'https', 'ftp'].member?(uri.scheme)
        kind = :fetched

        if uri.to_s.end_with?('.rb')
          type = :virtual
          name = File.basename(uri.to_s).sub('.rb', '')
        else
          xml = open(uri).read
          dom = Nokogiri::XML.parse(xml)

          type = dom.root['type'].to_sym
          name = dom.root['name']
        end
      elsif @@scm.member?(uri.scheme)
        kind = :scm

        FileUtils.rm_rf("#{System.env[:TMP]}/.__repo", :secure => true)

        _checkout(uri, "#{System.env[:TMP]}/.__repo")

        dom = Nokogiri::XML.parse(File.read("#{System.env[:TMP]}/.__repo/repository.xml"))

        type = dom.root['type'].to_sym
        name = dom.root['name']
      end

      if !kind
        CLI.fatal "I don't know what to do with #{uri}"
        next
      end

      path = "#{System.env[:REPOSITORIES]}/#{type}/#{name}"

      if Models::Repository.first(:type => type, :name => name)
        CLI.fatal "#{type}/#{name} already exists, delete it first"
        exit 10
      end

      case type
        when :binary
          path << '.xml'

          FileUtils.mkpath(File.dirname(path))
          File.write(path, open((kind == :file && (!uri.to_s.end_with?('.xml'))) ?
            "#{uri}/repository.xml" :
            uri
          ).read)

        when :source
          FileUtils.rm_rf path, :secure => true rescue nil
          FileUtils.mkpath path rescue nil

          case kind
            when :fetched
              _checkout(dom.xpath('//address').first.text, path)

            when :scm
              FileUtils.cp_r "#{System.env[:TMP]}/.__repo/.", path, :preserve => true

            else
              _checkout(uri.to_s, path)
          end

        when :virtual
          path << '.rb'

          FileUtils.mkpath(File.dirname(path))
          File.write(path, open((kind == :file && (!uri.to_s.end_with?('.rb'))) ?
            "#{uri}/repository.rb" :
            uri
          ).read)
      end

      begin
        _add type, name, uri, path
        CLI.info "Added #{type}/#{name}"
      rescue Exception => e
        CLI.fatal 'Failed to add the cache'
        Packo.debug e

        _delete(type, name)
      end
    }
  end


  desc 'delete REPOSITORY...', 'Delete installed repositories'
  map '-d' => :delete, '-R' => :delete
  def delete (*names)
    names.each {|name|
      repository = Packo::Repository.parse(name)

      if repository.type && !Packo::Repository::Types.member?(repository.type)
        CLI.fatal "#{repository.type} is not a valid repository type"
        exit 20
      end

      conditions        = Hash[:name => repository.name]
      conditions[:type] = repository.type if repository.type

      repositories = Models::Repository.all(conditions)

      if repositories.empty?
        CLI.fatal "#{repository.type}/#{repository.name} doesn't exist"
        exit 21
      end

      CLI.info "Deleting #{[repository.type, repository.name].join('/')}"

      begin
        repositories.each {|repository|
          FileUtils.rm_rf repository.path, :secure => true

          _delete(repository.type, repository.name)
        }
      rescue Exception => e
        CLI.fatal "Something went wrong while deleting #{name}"

        Packo.debug e
      end
    }
  end

  desc 'update', 'Update installed repositories'
  map '-u' => :update
  method_option :force, :type => :boolean, :default => false, :aliases => '-f', :desc => 'Force the update'
  def update
    Models::Repository.all.each {|repository|
      updated = false

      type = repository.type
      name = repository.name
      uri  = repository.uri.to_s
      path = repository.path

      case repository.type
        when :binary
          if (content = open(uri).read) != File.read(path) || options[:force]
            _delete(:binary, name)
            File.write(path, content)
            _add(:binary, name, uri, path)

            updated = true
          end

        when :source
          if _update(path) || options[:force]
            _delete(:source, name)
            _add(:source, name, uri, path)

            updated = true
          end

        when :virtual
      end

      if updated
        CLI.info "Updated #{type}/#{name}"
      else
        CLI.info "#{type}/#{name} already up to date"
      end
    }
  end

  desc 'search [EXPRESSION] [OPTIONS]', 'Search packages with the given expression'
  map '--search' => :search, '-Ss' => :search
  method_option :exact,      :type => :boolean, :default => false, :aliases => '-e', :desc => 'Search for the exact name'
  method_option :full,       :type => :boolean, :default => false, :aliases => '-F', :desc => 'Include the repository that owns the package'
  method_option :type,       :type => :string,                     :aliases => '-t', :desc => 'The repository type' 
  method_option :repository, :type => :string,                     :aliases => '-r', :desc => 'Set a specific repository'
  def search (expression='')
    Models.search(expression, options[:exact], options[:repository], options[:type]).group_by {|package|
      "#{package.tags}/#{package.name}"
    }.sort.each {|(name, packages)|
      if options[:full]
        packages.group_by {|package|
          "#{package.repository.type}/#{package.repository.name}"
        }.each {|name, packages|
          print "#{"#{packages.first.tags}/" unless packages.first.tags.empty?}#{packages.first.name.bold}"

          print ' ('
          print packages.map {|package|
            "#{package.version.to_s.red}" + (package.slot ? "%#{package.slot.to_s.blue.bold}" : '')
          }.join(', ')
          print ')'

          print " <#{"#{package.repository.type}/#{package.repository.name}".black.bold} | #{package.repository.uri} | #{package.repository.path}>"
        }
      else
        print "#{packages.first.tags}/#{packages.first.name.bold} ("

        print packages.map {|package|
          "#{package.version.to_s.red}" + (package.slot ? "%#{package.slot.to_s.blue.bold}" : '')
        }.join(', ')

        print ")"
      end
      
      print "\n"
    }
  end

  desc 'info [EXPRESSION] [OPTIONS]', 'Search packages with the given expression and return detailed informations about them'
  map '--info' => :info, '-I' => :info
  method_option :exact,      :type => :boolean, :default => false, :aliases => '-e', :desc => 'Search for the exact name'
  method_option :type,       :type => :string,                     :aliases => '-t', :desc => 'The repository type' 
  method_option :repository, :type => :string,                     :aliases => '-r', :desc => 'Set a specific repository'
  def info (expression='')
    Models.search(expression, options[:exact], options[:repository], options[:type]).group_by {|package|
      package.name
    }.sort.each {|(name, packages)|
      packages.sort {|a, b|
        a.version <=> b.version
      }.each {|package|
        print "<#{"source/#{package.repository.name}".black.bold}> "
        print package.name.bold
        print "-#{package.version.to_s.red}"
        print " {#{package.revision.yellow.bold}}" if package.revision > 0
        print " (#{package.slot.blue.bold})" if package.slot
        print " [#{package.tags.join(' ').magenta}]" if !package.tags.empty?
        print "\n"

        puts "    #{'Description'.green}: #{package.description}"      if package.description
        puts "    #{'Homepage'.green}:    #{package.homepage}"         if package.homepage
        puts "    #{'License'.green}:     #{package.license}"          if package.license
        puts "    #{'Maintainer'.green}:  #{package.model.maintainer}" if package.maintainer

        case package.repository.type
          when :binary
            puts "    #{'Features'.green}:    #{package.features.to_a.select {|f| f.enabled?}.map {|f| f.name}.join(' ')}"

            print "    #{'Builds'.green}:      "
            package.model.data.builds.each {|build|
              print 'With '

              if !build.features.empty?
                print build.features.bold
              else
                print 'nothing'
              end

              print " in #{build.flavor.bold} flavor" if build.flavor
              print " (SHA1 #{build.digest})".black.bold if build.digest
              print "\n                 "
            }

          when :source
            length = (package.model.data.flavor.to_a + package.model.data.features.to_a).map {|f|
              f.name.length
            }.max

            if package.model.data.flavor.length > 0
              print "    #{'Flavor'.green}:      "

              flavor = package.model.data.flavor

              flavor.each {|element|
                if element.enabled
                  print "#{element.name.white.bold}#{System.env[:NO_COLORS] ? '!' : ''}"
                else
                  print element.name.black.bold
                end

                print "#{' ' * (4 + length - element.name.length + (System.env[:NO_COLORS] && !element.enabled ? 1 : 0))}#{element.description || '...'}"

                print "\n                   "
              }

              print "\r" if package.model.data.features.length > 0
            end

            if package.model.data.features.length > 0
              print "    #{'Features'.green}:    "

              features = package.model.data.features

              features.each {|feature|
                if feature.enabled
                  print "#{feature.name.white.bold}#{System.env[:NO_COLORS] ? '!' : ''}"
                else
                  print feature.name.black.bold
                end

                print "#{' ' * (4 + length - feature.name.length + (System.env[:NO_COLORS] && !feature.enabled ? 1 : 0))}#{feature.description || '...'}"

                print "\n                 "
              }
            end
        end

        print "\n"
      }
    }
  end

  desc 'list [TYPE]', 'List installed repositories'
  def list (type='all')
    if Packo::Repository::Types.member?(type.to_sym)
      CLI.info "Installed #{type} repositories:"

      repositories = Models::Repository.all(:type => type)
      length       = repositories.map {|repository| "#{repository.type}/#{repository.name}".length}.max

      repositories.each {|repository|
        puts "  #{repository.type}/#{repository.name}#{' ' * (4 + length - "#{repository.type}/#{repository.name}".length)}#{repository.uri} (#{repository.path})"
      }

      puts ''
    elsif type == 'all'
      Packo::Repository::Types.each {|type|
        list(type)
      }
    end
  end

  desc 'path REPOSITORY', 'Output the path of a given repository'
  def path (name)
    repository = Models::Repository.first(Packo::Repository.parse(name).to_hash)

    exit if !repository

    puts repository.path
  end

  desc 'uri REPOSITORY', 'Output the URI of a given package'
  def uri (name)
    repository = Models::Repository.first(Packo::Repository.parse(name).to_hash)

    exit if !repository

    puts repository.URI
  end

  desc 'rehash REPOSITORY...', 'Rehash the repository caches'
  def rehash (*names)
    repositories = []

    if names.empty?
      repositories << Models::Repository.all
    else
      names.each {|name|
        repositories << Models::Repository.all(:name => name)
      }
    end

    repositories.flatten.compact.each {|repository|
      type = repository.type
      name = repository.name
      uri  = repository.uri
      path = repository.path

      CLI.info "Rehashing #{type}/#{name}"

      _delete(type, name)

      case type
        when :binary
          _add(:binary, name, uri, path)

        when :source
          _add(:source, name, uri, path)
      end
    }
  end

  private

  def _add (type, name, uri, path)
    Helpers::Repository.wrap(Models::Repository.create(
      :type => type,
      :name => name,

      :uri  => uri,
      :path => path
    )).populate
  end

  def _delete (type, name)
    Models::Repository.first(:name => name, :type => type).destroy rescue nil
  end

  def _checkout (uri, path)
    uri = URI.parse(uri.to_s) if !uri.is_a?(URI)

    if !uri.scheme
      if File.directory?("#{uri}/.git")
        scm = 'git'
      end
    else
      scm = uri.scheme
    end

    if !@@scm.member?(scm)
      CLI.fatal "#{scm} is an unsupported SCM"
      exit 40
    end

    case scm
      when 'git'; Packo.sh 'git', 'clone', '--depth', '1', uri.to_s, path, :silent => !System.env[:VERBOSE]
    end
  end

  def _update (path)
    result = false

    old = Dir.pwd; Dir.chdir(path)

    if !result && (`git reset --hard`) && (`git pull`.strip != 'Already up-to-date.' rescue nil)
      result = true
    end

    Dir.chdir(old)

    return result
  end
end

end; end
