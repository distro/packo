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

module Packo; module RBuild; module Modules; module Fetching

Fetcher.register :github do |url, package|
  whole, user, project, file = url.interpolate(package).match(%r{^(.*?)/(.*?)/(.*?)$}).to_a

  CLI.warn 'Github has problems with certificates in the download page.'
  CLI.warn 'If you are using wget you must add --no-check-certificate to the options.'

  ["https://github.com/#{user}/#{project}/tarball/#{file}", "#{project}-#{file}.tar.gz"]
end

end; end; end; end
