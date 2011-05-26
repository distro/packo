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

require 'base64'

module Packo; module RBuild; class Package < Packo::Package

class Manifest
  def self.parse (text)
    data = YAML.parse(text).transform

    Manifest.new(OpenStruct.new(
      maintainer: data['package']['maintainer'],

      tags:    Packo::Package::Tags.parse(data['package']['tags']),
      name:    data['package']['name'],
      version: Versionomy.parse(data['package']['version']),
      slot:    data['package']['slot'],

      exports: Marshal.load(Base64.decode64(data['package']['exports'])),

      description: data['package']['description'],
      homepage:    data['package']['homepage'].split(/\s+/),
      license:     data['package']['license'].split(/\s+/),

      flavor:   Packo::Package::Flavor.parse(data['package']['flavor'] || ''),
      features: Packo::Package::Features.parse(data['package']['features'] || ''),

      environment: data['package']['environment'],

      dependencies: data['dependencies'].map {|dependency|
        Package::Dependency.parse(dependency)
      },

      blockers: data['blockers'].map {|blocker|
        Package::Blocker.parse(blocker)
      },

      selector: data['selectors']
    ))
  end

  def self.open (path)
    Manifest.parse(File.read(path))
  end

  attr_reader :package, :dependencies, :blockers, :selectors

  def initialize (what)
    @package = OpenStruct.new(
      maintainer: what.maintainer,

      tags:    what.tags,
      name:    what.name,
      version: what.version,
      slot:    what.slot,

      exports: what.exports,

      description: what.description,
      homepage:    [what.homepage].flatten.compact.join(' '),
      license:     [what.license].flatten.compact.join(' '),

      flavor:   what.flavor,
      features: what.features,

      environment: what.environment!.reject {|name, value|
        [:DATABASE, :FLAVORS, :PROFILES, :CONFIG_PATH, 
         :REPOSITORIES, :SELECTORS, :FETCHER,
         :NO_COLORS, :DEBUG, :VERBOSE, :TMP, :SECURE
        ].member?(name.to_sym)
      }
    )

    @dependencies = what.dependencies
    @blockers     = what.blockers
    @selectors    = [what.selector].flatten.compact.map {|selector| OpenStruct.new(selector)}

    if (what.filesystem.selectors rescue false)
      what.filesystem.selectors.each {|name, file|
        matches = file.content.match(/^#\s*(.*?):\s*(.*)([\n\s]*)?\z/) or next

        @selectors << OpenStruct.new(name: matches[1], description: matches[2], path: name)
      }
    end
  end

  def to_yaml
    <<-PACKAGE.gsub(/^ {6}/, '')
      ---
      package:
        tags:     #{package.tags}
        name:     #{package.name}
        version:  #{package.version}
        slot:     #{package.slot}
        revision: #{package.revision}

        descripion: #{package.description.inspect}
        homepage:   #{package.homepage.inspect}
        license:    #{package.license.inspect}

        maintainer: #{package.maintainer.inspect}

        flavor:   #{package.flavor}
        features: #{package.features}

        environment: #{package.environment.map {|(name, value)|
          "\n    #{name}: #{value.to_s.inspect}"
        }.join}

        exports: #{Base64.encode64(Marshal.dump(package.exports)).gsub("\n", '')}

      dependencies: #{dependencies.map {|dependency|
        "\n  - #{dependency.to_s.inspect}"
      }.join}

      blockers: #{blockers.map {|blocker|
        "\n  - #{blocker.to_s.inspect}"
      }.join}

      selectors:
      #{selectors.map {|selector|
        <<-SELECTOR.gsub(/^ {8}/, '')
          - name:        #{selector.name.to_s.inspect}
            description: #{selector.description.to_s.inspect}
            path:        #{selector.path.to_s.inspect}
        SELECTOR
      }.join("\n")}
    PACKAGE
  end

  def save (to, options={})
    File.write(to, self.to_s)
  end

  def to_s (options={})
    to_yaml
  end
end

end; end; end
