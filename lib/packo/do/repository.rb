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

require 'uri'

require 'packo'

require 'packo/do/vcs'
require 'packo/do/repository/helpers'

module Packo; class Do
  
class Repository
  class Model
    def self.add (type, name, location, path, populate=true)
      require 'packo/models'

      repo = Helpers::Repository.wrap(Models::Repository.create(
        type: type,
        name: name,

        location: location,
        path:     path
      ))

      repo.populate if populate

      repo
    end

    def self.delete (type, name)
      require 'packo/models'

      Models::Repository.first(name: name, type: type).destroy
    end
  end

  class Remote
    def self.add (uri)
      uri = URI.parse(uri)
    end

    def self.delete (name)

    end

    def self.get (name)
      Models.remote(name).location rescue nil
    end
  end

  def self.add (location)
    type, name = nil

    Do.rm("#{System.env[:TMP]}/.__packo.repo")

    if location.type == :file
      if location.path.end_with?('.rb')
        location.path = File.realpath(location.path)

        type = :virtual
        name = File.basename(location.path).sub('.rb', '')
      else
        location.path = File.realpath(location.path)

        if File.directory?(location.path)
          dom = Nokogiri::XML.parse(File.read("#{location.path}/repository.xml"))
        else
          dom = Nokogiri::XML.parse(File.read(location.path))
        end

        type = dom.root['type'].to_sym
        name = dom.root['name']

        if type == :source
          path = location.path

          location = Location[dom.xpath('//location').first]
          location.repository = path
        end
      end
    elsif location.type == :url
      if location.address.end_with?('.rb')
        type = :virtual
        name = File.basename(location.address).sub('.rb', '')
      else
        dom = Nokogiri::XML.parse(open(location.address).read)

        type = dom.root['type'].to_sym
        name = dom.root['name']
      end
    else
      Do::VCS.checkout(location, "#{System.env[:TMP]}/.__packo.repo")

      dom = Nokogiri::XML.parse(File.read("#{System.env[:TMP]}/.__packo.repo/repository.xml"))

      type = dom.root['type'].to_sym
      name = dom.root['name']
    end

    path = "#{System.env[:REPOSITORIES]}/#{type}/#{name}"

    if Models::Repository.first(type: type, name: name)
      CLI.fatal "#{type}/#{name} already exists, delete it first"
      exit 10
    end

    case type
      when :binary
        path << '.xml'

        FileUtils.mkpath(File.dirname(path))
        File.write(path, open((location.type == :file && (!location.path.end_with?('.xml'))) ?
          "#{location.path}/repository.xml" :
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
      repository = Do::Repository::Model.add type, name, location, path, !(type == :virtual && options[:ignore])
    }

    repository
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

  def self.generate (path)
    dom = Nokogiri::XML.parse(File.read(path)) {|config|
      config.default_xml.noblanks
    }

    dom.xpath('//packages/package').each {|e|
      CLI.info "Generating #{Packo::Package.new(tags: e['tags'].split(/\s+/), name: e['name'])}".bold if System.env[:VERBOSE]

      e.xpath('.//build').each {|build|
        package = Package.new(
          tags:     e['tags'],
          name:     e['name'],
          version:  build.parent['name'],
          slot:     (build.parent.parent.name == 'slot') ? build.parent.parent['name'] : nil,

          repository: options[:repository]
        )

        package.flavor   = (build.xpath('.//flavor').first.text rescue '')
        package.features = (build.xpath('.//features').first.text rescue '')

        next if File.exists?("#{options[:output]}/#{dom.root['name']}/#{package.tags.to_s(true)}/" +
          "#{package.name}-#{package.version}#{"%#{package.slot}" if package.slot}" +
          "#{"+#{package.flavor.to_s(:package)}" if !package.flavor.to_s(:package).empty?}" +
          "#{"-#{package.features.to_s(:package)}" if !package.features.to_s(:package).empty?}" +
          '.pko'
        )

        begin
          pko = _build(package,
            FLAVOR:   package.flavor,
            FEATURES: package.features
          )

          build.xpath('.//digest').each {|node| node.remove}
          build.add_child dom.create_element('digest', Packo.digest(pko))

          FileUtils.mkpath "#{options[:output]}/#{dom.root['name']}/#{package.tags.to_s(true)}"
          FileUtils.mv pko, "#{options[:output]}/#{dom.root['name']}/#{package.tags.to_s(true)}"
        rescue Exception => e
          Packo.debug e
        end

        File.write(path, dom.to_xml(indent: 4))
      }
    }
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
      Packo.loadPackage("#{tmp.last.repository.path}/#{tmp.last.model.data.path}", tmp.last)
    ).to_s
  end
end

end; end
