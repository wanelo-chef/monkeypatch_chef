#
# Authors:: Trevor O (trevoro@joyent.com)
#           Bryan McLellan (btm@loftninjas.org)
#           Matthew Landauer (matthew@openaustralia.org)
#           Ben Rockwood (benr@joyent.com)
# Copyright:: Copyright (c) 2009 Bryan McLellan, Matthew Landauer
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

class Chef
  class Provider
    class Package
      class SmartOS < Chef::Provider::Package
        def candidate_version
          return @candidate_version if @candidate_version
          name = nil
          version = nil
          pkg = shell_out!("/opt/local/bin/pkgin se #{new_resource.package_name}", :env => nil, :returns => [0,1])
          pkg.stdout.each_line do |line|
            case line
            when /^#{new_resource.package_name}-([^-]+)$/
              name, version = line.split[0].split(/-([^-]+)$/)
            end
          end
          @candidate_version = version
          version
        end
      end
    end
  end
end
