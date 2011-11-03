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

require 'packo/fixes'

require 'ostruct'
require 'pathname'
require 'fileutils'
require 'yaml'
require 'memoized'
require 'shellwords'
require 'cgi'
require 'open-uri'
require 'versionub'
require 'boolean/expression'
require 'refining'
require 'fffs'
require 'find'
require 'forwardable'

Path = Pathname

class Pathname
	def self.[] (path)
		Pathname.new(path).cleanpath.to_s
	end

	def self.clean (path)
		Pathname.new(path).cleanpath.to_s
	end
end

module StructLike
	def method_missing (id, *args)
		@data ||= {}

		id = id.to_s.sub(/[=?]$/, '').to_sym

		if args.length == 0
			return @data[id]
		else
			if respond_to? "#{id}="
				send "#{id}=", *args
			else
				value = (args.length > 1) ? args : args.first

				if value.nil?
					@data.delete(id)
				else
					@data[id] = value
				end
			end
		end
	end

	def to_hash
		@data.clone
	end
end

class Object
	def numeric?
		true if Float(self) rescue false
	end
end

module Kernel
	def suppress_warnings
		exception = nil
		tmp, $VERBOSE = $VERBOSE, nil

		begin
			result = yield
		rescue Exception => e
			exception = e
		end

		$VERBOSE = tmp

		if exception
			raise exception
		else
			result
		end
	end

	def catch_output
		require 'stringio'

		exception = nil
		result    = StringIO.new

		out, err, $stdout, $stderr = $stdout, $stderr, result, result

		begin
			yield
		rescue Exception => e
			exception = e
		end

		$stdout, $stderr = out, err

		if exception
			raise exception
		else
			result.rewind
			result.read
		end
	end
end

class File
	def self.write (path, data, mode = nil)
		open(path, 'wb') {|f|
			f.write data
			f.chmod mode if mode
		}
	end

	def self.append (path, data, mode = nil)
		open(path, 'ab') {|f|
			f.write data
			f.chmod mode if mode
		}
	end
end

class String
	def interpolate (on)
		on.instance_eval("%{#{self}}") rescue self
	end
end

module Shellwords
	refine_singleton_method(:shellescape) do |old, *args|
		old.call(args.first.to_s)
	end
end

class OpenStruct
	alias to_hash marshal_dump
	alias merge! marshal_load
	alias delete delete_field
end

module Process
	class << self
		def wait (*args)
			waitpid(*args)
		rescue Errno::ECHILD
			raise $! if args.size == 0

			pid = args.first

			begin # act like original wait
				Process.kill(0, pid)
			rescue Errno::EPERM
			end

			begin
				sleep 0.1 while Process.kill(0, pid) == 1
			rescue Errno::ESRCH
			rescue Errno::EPERM
				retry
			end
		end
	end
end

class IO
	def read_all_nonblock
		result = ''

		while (tmp = self.read_nonblock(4096) rescue nil)
			result << tmp
		end

		result
	end
end

module FileUtils
	class Entry_
		def copy! (dest)
			case
			when file?
				copy_file dest
			when directory?
				if !File.exist?(dest) and /^#{Regexp.quote(path)}/ =~ File.dirname(dest)
					raise ArgumentError, "cannot copy directory #{path} to itself #{dest}"
				end
				begin
					FileUtils.mkdir_p dest
				rescue
					raise unless File.directory?(dest)
				end
			when File.symlink?(path)
				FileUtils.ln_sf File.readlink(path), dest
			when chardev?
				raise "cannot handle device file" unless File.respond_to?(:mknod)
				mknod dest, ?c, 0666, lstat().rdev
			when blockdev?
				raise "cannot handle device file" unless File.respond_to?(:mknod)
				mknod dest, ?b, 0666, lstat().rdev
			when socket?
				raise "cannot handle socket" unless File.respond_to?(:mknod)
				mknod dest, nil, lstat().mode, 0
			when pipe?
				raise "cannot handle FIFO" unless File.respond_to?(:mkfifo)
				mkfifo dest, 0666
			when door?
				raise "cannot handle door: #{path()}"
			else
				raise "unknown file type: #{path()}"
			end
		end

		def copy_metadata! (dest)
			copy_metadata(dest) rescue nil
		end
	end

	def copy_entry! (src, dest, preserve = false, dereference_root = false, remove_destination = false)
		Entry_.new(src, nil, dereference_root).traverse do |ent|
			destent = Entry_.new(dest, ent.rel, false)
			File.unlink destent.path if remove_destination && File.file?(destent.path)
			ent.copy! destent.path
			ent.copy_metadata! destent.path if preserve
		end
	end
	module_function :copy_entry!

	def cp_rf(src, dest, options = {})
		fu_check_options options, OPT_TABLE['cp_r']
		fu_output_message "cp -rf#{options[:preserve] ? 'p' : ''}#{options[:remove_destination] ? ' --remove-destination' : ''} #{[src,dest].flatten.join ' '}" if options[:verbose]
		return if options[:noop]
		options = options.dup
		options[:dereference_root] = true unless options.key?(:dereference_root)

		mkdir_p(dest)
		fu_each_src_dest0(src, dest) do |s, d|
			copy_entry! s, d, options[:preserve], options[:dereference_root], options[:remove_destination]
		end
	end
	module_function :cp_rf
end
