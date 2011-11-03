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

module Packo; module RBuild

class Stages
	class Stage
		attr_reader :name, :options, :method

		def initialize (name, options, &method)
			@name    = name.to_sym
			@method  = method
			@options = options

			if (@options[:at] || @options[:after] == :beginning || @options[:before] == :ending) && @options[:strict].nil?
				@options[:strict] = true
			end

			@options[:priority] ||= 0
		end

		def call (*args)
			@method.(*args)
		end

		def == (value)
			@name == value || @method == value
		end

		def inspect
			"#<Stage: #{name} (#{@options.inspect})>"
		end
	end

	attr_reader :package, :stages

	def initialize (package)
		@package = package

		@stages    = []
	end

	def owner_of (name)
		name = name.to_sym

		@stages.find {|stage|
			stage.name == name
		}.method.owner rescue nil
	end

	def add (name, method = nil, options = nil, &block)
		options = method if method.is_a?(Hash)
		method  = block  if block

		@stages.delete_if {|stage|
			stage.name == name
		}

		@stages << Stage.new(name, options, &method)

		@sorted = false
	end

	def delete (name)
		@stages.delete_if {|stage|
			stage.name == name
		}

		@sorted = false
	end

	def sort! (strict = false)
		return if @sorted

		funcs = {
			atom: -> {
				{ stricts: [], normals: [] }
			},

			leaf: -> {
				Hash[
					after:  funcs[:atom].(),
					before: funcs[:atom].(),
					at:     funcs[:atom].(),
					stage:  nil
				]
			},

			type: -> stage {
				stage.options[:strict] ? :stricts : :normals
			},

			plain: -> pi {
				pi.sort {|a, b|
					pr = (a[:stage].options[:priority] || 0) <=> (b[:stage].options[:priority] || 0)
					pr.zero? ? a[:stage].name.to_s.downcase <=> b[:stage].name.to_s.downcase : pr
				}.map {|l|
					funcs[:flat].(l)
				}.flatten
			},

			flat: -> leaf {
				funcs[:plain].(leaf[:after][:normals]) + funcs[:plain].(leaf[:after][:stricts]) +
					(leaf[:stage] ? [leaf[:stage]] : (funcs[:plain].(leaf[:at][:stricts]) + funcs[:plain].(leaf[:at][:normals]))) +
					funcs[:plain].(leaf[:before][:stricts]) + funcs[:plain].(leaf[:before][:normals])
			}
		}

		tree = { beginning: funcs[:leaf].(), end: funcs[:leaf].() }

		remained = @stages.dup
		prev_rem = @stages.size

		begin
			prev_rem = remained.size

			remained.dup.each {|stage|
				place = (if tree[stage.options[:after]]
					[stage.options[:after], :before, funcs[:type].(stage)]
				elsif tree[stage.options[:before]]
					[stage.options[:before], :after, funcs[:type].(stage)]
				elsif [:beginning, :end].include?(stage.options[:at])
					[stage.options[:at], :at, funcs[:type].(stage)]
				else
					nil
				end)

				next unless place

				remained.delete(stage)

				leaf         = funcs[:leaf].()
				leaf[:stage] = stage

				tree[place[0]][place[1]][place[2]] << leaf

				tree[stage.name.to_sym] = leaf
			}
		end while prev_rem != remained.size

		tree[:beginning][:after] = tree[:end][:before] = funcs[:atom].()

		@stages = funcs[:flat].(tree[:beginning]) + funcs[:flat].(tree[:end])
		@sorted = true
	end

	def stop!;    @stopped = true;  end
	def restart!; @stopped = false; end

	def each (&block)
		self.sort!

		@stages.each {|stage|
			block.call stage

			break if @stopped
		}
	end
end

end; end
