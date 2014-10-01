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
            when /^#{new_resource.package_name}-([^-\s]+)\s/
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

class Chef
  class Provider
    class Cron
      class Unix < Chef::Provider::Cron
        include ::Chef::Mixin::ShellOut

        private

        def read_crontab
          crontab = shell_out('/usr/bin/crontab -l', :user => @new_resource.user)
          status = crontab.status.exitstatus

          Chef::Log.debug crontab.format_for_exception if status > 0

          if status > 1
            raise Chef::Exceptions::Cron, "Error determining state of #{@new_resource.name}, exit: #{status}"
          end
          return nil if status > 0
          crontab.stdout.chomp << "\n"
        end


        def write_crontab(crontab)
          tempcron = Tempfile.new("chef-cron")
          tempcron << crontab
          tempcron.flush
          tempcron.chmod(0644)
          exit_status = 0
          error_message = ""
          begin
            crontab_write = shell_out("/usr/bin/crontab #{tempcron.path}", :user => @new_resource.user)
            stderr = crontab_write.stderr
            exit_status = crontab_write.status.exitstatus
            # solaris9, 10 on some failures for example invalid 'mins' in crontab fails with exit code of zero :(
            if stderr && stderr.include?("errors detected in input, no crontab file generated")
              error_message = stderr
              exit_status = 1
            end
          rescue Chef::Exceptions::Exec => e
            Chef::Log.debug(e.message)
            exit_status = 1
            error_message = e.message
          rescue ArgumentError => e
            # usually raised on invalid user.
            Chef::Log.debug(e.message)
            exit_status = 1
            error_message = e.message
          end
          tempcron.close!
          if exit_status > 0
            raise Chef::Exceptions::Cron, "Error updating state of #{@new_resource.name}, exit: #{exit_status}, message: #{error_message}"
          end
        end
      end
    end
  end
end

