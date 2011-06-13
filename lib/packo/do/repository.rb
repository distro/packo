#--
# Copyleft meh. [http://meh.paranoid.pk | meh@paranoici.org]
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

require 'packo'

require 'packo/do/vcs'

require 'packo/do/repository/model'
require 'packo/do/repository/remote'

require 'packo/do/repository/binary'
require 'packo/do/repository/source'
require 'packo/do/repository/virtual'

module Packo; class Do
  
class Repository
  def self.add (location)
    data, type, name = nil

    FileUtils.rm_rf("#{System.env[:TMP]}/.__packo.repo", secure: true)

    if location.type == :file
      if location.path.end_with?('.rb')
        location.path = File.realpath(location.path)

        type = :virtual
        name = File.basename(location.path).sub('.rb', '')
      else
        location.path = File.realpath(location.path)

        if File.directory?(location.path)
          data = YAML.parse_file("#{location.path}/repository.yml").transform
        else
          data = YAML.parse_file(location.path).transform
        end

        type = data['type'].to_sym
        name = data['name']

        if type == :source
          path = location.path

          location = Location[data['location']]
          location.repository = path
        end
      end
    elsif location.type == :url
      if location.address.end_with?('.rb')
        type = :virtual
        name = File.basename(location.address).sub('.rb', '')
      else
        data = YAML.parse_file(location.address).transform

      end
    else
      Do::VCS.checkout(location, "#{System.env[:TMP]}/.__packo.repo")

      data = YAML.parse_file("#{System.env[:TMP]}/.__packo.repo/#{location.path || 'repository.yml'}").transform
    end

    type = data['type'].to_sym if !type && data
    name = data['name']        if !name && data

    path = "#{System.env[:MAIN_PATH]}/repositories/#{type}/#{name}"

    if Models::Repository.first(type: type, name: name)
      CLI.fatal "#{type}/#{name} already exists, delete it first"
      exit 10
    end

    case type
      when :binary
        path << '.yml'

        FileUtils.mkpath(File.dirname(path))
        File.write(path, open((location.type == :file && (!location.path.end_with?('.yml'))) ?
          "#{location.path}/repository.yml" :
          location.path || location.address
        ).read)

      when :source
        FileUtils.rm_rf path, secure: true rescue nil
        FileUtils.mkpath path rescue nil

        if File.directory?("#{System.env[:TMP]}/.__packo.repo")
          FileUtils.cp_r "#{System.env[:TMP]}/.__packo.repo/.", path, preserve: true
        else
          Do::VCS.checkout(location, path)
        end

      when :virtual
        path << '.rb'

        FileUtils.mkpath(File.dirname(path))
        File.write(path, open((location.type == :file && (!location.path.end_with?('.rb'))) ?
          "#{location.path}/repository.rb" :
          location.path || location.address
        ).read)
    end

    Models.transaction {
      Do::Repository::Model.add type, name, location, path, !(type == :virtual && options[:ignore])
    }
  end

  def self.delete (repository)
    path = repository.path
    
    Do::Repository::Model.delete(repository.type, repository.name)
    
    FileUtils.rm_rf path, secure: true
  end

  def self.update (repository, options={})
    updated = false

    type     = repository.type
    name     = repository.name
    location = repository.location
    path     = repository.path

    Models.transaction {
      case type
        when :binary
          if (content = open(location.path || location.address).read) != File.read(path) || options[:force]
            Do::Repository::Model.delete(:binary, name)
            File.write(path, content)
            Do::Repository::Model.add(:binary, name, location, path)

            updated = true
          end

        when :source
          if Do::VCS.update(location, path) || options[:force]
            Do::Repository::Model.delete(:source, name)
            Do::Repository::Model.add(:source, name, location, path)

            updated = true
          end

        when :virtual
          if (content = open(location.path || location.address).read != File.read(path)) || options[:force]
            Do::Repository::Model.delete(:virtual, name)
            File.write(path, content)
            Do::Repository::Model.add(:vitual, name, location, path, !options[:ignore])

            updated = true
          end
      end
    }

    updated
  end

  def self.rehash (repository)
    type     = repository.type
    name     = repository.name
    location = repository.location
    path     = repository.path

    Models.transaction {
      Do::Repository::Model.delete(type, name)

      case type
        when :binary
          Do::Repository::Model.add(:binary, name, location, path)

        when :source
          Do::Repository::Model.add(:source, name, location, path)

        when :virtual
          Do::Repository::Model.add(:virtual, name, location, path)
      end
    }
  end

  def self.generate (path, options={ output: "#{System.env[:TMP]}/generated" })
    require 'packo/do/build'

    data       = YAML.parse_file(path).transform
    repository = data['name'].gsub('/', '-')

    data['packages'].each {|name, data|
      CLI.info "Generating #{name}".bold if System.env[:VERBOSE]    

      data['builds'].each {|build|
        package = Package.parse(name)

        next if File.exists?("#{options[:output]}/#{repository}/#{package.tags.to_s(true)}") && !options[:wipe]

        package.version = build['version'] if build['version']
        package.slot    = build['slot']    if build['slot']

        if build['repository'] || data['repository']
          package.repository = build['repository'] || data['repository']
        end

        package.flavor   = build['flavor']   if build['flavor']
        package.features = build['features'] if build['features']

        begin
          result = Do::Build.build(package, env: { FLAVOR: package.flavor, FEATURES: package.features }) {|stage|
            CLI.info "Executing #{stage.name}"
          }

          build['digest'] = Packo.digest(result)

          FileUtils.mkpath "#{options[:output]}/#{repository}/#{package.tags.to_s(true)}"
          FileUtils.cp result, "#{options[:output]}/#{repository}/#{package.tags.to_s(true)}"
        rescue Exception => e
          Packo.debug e
        end
      }
    }

    data.to_yaml
  end

  def self.has (package, env)
    !!Models.search(package.to_s(:whole), package.repository.name, package.repository.type).find {|package|
      !!package.model.data.builds.to_a.find {|build|
        build.features.split(/\s+/).sort == env[:FEATURES].split(/\s+/).sort && \
        build.flavor.split(/\s+/).sort   == env[:FLAVOR].split(/\s+/).sort
      }
    }
  end

  def self.digest (package, env)
    Models.search(package, package.repository.name, :binary).find {|package|
      package.model.data.builds.to_a.find {|build|
        build.features.split(/\s+/).sort == env[:FEATURES].split(/\s+/).sort && \
        build.flavor.split(/\s+/).sort   == env[:FLAVOR].split(/\s+/).sort
      }
    }.model.data.digest
  end

  def self.manifest (package, options={})
    tmp = Models.search(package.to_s, options)

    RBuild::Package::Manifest.new(
      RBuild::Package.load("#{tmp.last.repository.path}/#{tmp.last.model.data.path}", tmp.last)
    ).to_s
  end
end

end; end
