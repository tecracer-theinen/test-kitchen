# -*- encoding: utf-8 -*-
#
# Author:: Fletcher Nichol (<fnichol@nichol.ca>)
#
# Copyright (C) 2012, Fletcher Nichol
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'benchmark'
require 'fog'

require 'jamie'

module Jamie

  module Driver

    # Amazon EC2 driver for Jamie.
    #
    # @author Fletcher Nichol <fnichol@nichol.ca>
    class Ec2 < Jamie::Driver::SSHBase

      default_config :region,             'us-east-1'
      default_config :availability_zone,  'us-east-1b'
      default_config :flavor_id,          'm1.small'
      default_config :groups,             [ 'default' ]
      default_config :username,           'root'
      default_config :port,               '22'

      def create(state)
        server = create_server
        state[:server_id] = server.id

        info("EC2 instance <#{state[:server_id]}> created.")
        server.wait_for { print "."; ready? } ; print "(server ready)"
        state[:hostname] = server.public_ip_address
        wait_for_sshd(state[:hostname])      ; print "(ssh ready)\n"
      rescue Fog::Errors::Error, Excon::Errors::Error => ex
        raise ActionFailed, ex.message
      end

      def destroy(state)
        return if state[:server_id].nil?

        server = connection.servers.get(state[:server_id])
        server.destroy unless server.nil?
        info("EC2 instance <#{state[:server_id]}> destroyed.")
        state.delete(:server_id)
        state.delete(:hostname)
      end

      private

      def connection
        Fog::Compute.new(
          :provider               => :aws,
          :aws_access_key_id      => config[:aws_access_key_id],
          :aws_secret_access_key  => config[:aws_secret_access_key],
          :region                 => config[:region],
        )
      end

      def create_server
        connection.servers.create(
          :availability_zone  => config[:availability_zone],
          :groups             => config[:groups],
          :flavor_id          => config[:flavor_id],
          :image_id           => config[:image_id],
          :key_name           => config[:aws_ssh_key_id],
        )
      end
    end
  end
end
