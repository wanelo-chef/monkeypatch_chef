#
# Copyright:: Copyright (c) 2012 Opscode, Inc.
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

require 'pathname'
require 'chef/mixin/shell_out'
require 'chef/provider/user'

class Chef
  class Provider
    class User
      class Useradd < Chef::Provider::User

        def create_user
          command = compile_command("useradd") do |useradd|
            useradd.concat(universal_options)
            useradd.concat(useradd_options)
          end
          shell_out!(*command)

          unlock_user if node['platform'] == 'smartos'
          lock_pass if new_resource.system && node['platform'] == 'smartos'
        end

        def lock_user
          return if check_lock
          case node['platform']
            when 'smartos'
              shell_out!("passwd", "-l", @new_resource.username)
            else
              shell_out!("usermod", "-L", new_resource.username)
          end
        end

        def unlock_user
          case node['platform']
            when 'smartos'
              shell_out!("passwd", "-u", @new_resource.username)
            else
              shell_out!("usermod", "-U", new_resource.username)
          end
        end

        def lock_pass
          shell_out!("passwd -N #{@new_resource.username}")
        end

        def unlock_pass
          shell_out!("passwd -d #{@new_resource.username}")
        end

        def check_lock
          # we can get an exit code of 1 even when it's successful on
          # rhel/centos (redhat bug 578534). See additional error checks below.
          passwd_s = check_lock_status
          status_line = passwd_s.stdout.split(' ')
          case status_line[1]
          when /^P/
            @locked = false
          when /^N/
            @locked = false
          when /^L/
            @locked = true
          end

          unless passwd_s.exitstatus == 0
            raise_lock_error = false
            if ['redhat', 'centos'].include?(node[:platform])
              passwd_version_check = shell_out!('rpm -q passwd')
              passwd_version = passwd_version_check.stdout.chomp

              unless passwd_version == 'passwd-0.73-1'
                raise_lock_error = true
              end
            else
              raise_lock_error = true
            end

            raise Chef::Exceptions::User, "Cannot determine if #{new_resource} is locked!" if raise_lock_error
          end

          @locked
        end

        # Illumos useradd does not have a concept of a "system" user, so the
        # normal chef code does not apply
        def useradd_options
          opts = []
          opts << "-r" if new_resource.system && node['platform'] != 'smartos'
          opts
        end

        private

        def check_lock_status
          case node['platform']
            when 'smartos'
              shell_out!("passwd", "-s", @new_resource.username, :returns => [0, 1])
            else
              shell_out!("passwd", "-S", new_resource.username, :returns => [0, 1])
          end
        end
      end
    end
  end
end
