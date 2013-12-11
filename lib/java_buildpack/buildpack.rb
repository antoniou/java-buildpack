# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright 2013 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'java_buildpack'
require 'java_buildpack/component/additional_libraries'
require 'java_buildpack/component/application'
require 'java_buildpack/component/droplet'
require 'java_buildpack/component/immutable_java_home'
require 'java_buildpack/component/java_opts'
require 'java_buildpack/component/mutable_java_home'
require 'java_buildpack/logging/logger_factory'
require 'java_buildpack/util/configuration_utils'
require 'java_buildpack/util/constantize'
require 'java_buildpack/util/snake_case'
require 'java_buildpack/util/space_case'
require 'pathname'

module JavaBuildpack

  # Encapsulates the detection, compile, and release functionality for Java application
  class Buildpack

    # Main entry to the buildpack.  Initializes the buildpack and all of its dependencies and yields a new instance
    # to any given block.  Any exceptions thrown as part of the buildpack setup or execution are handled
    #
    # @param [String] app_dir the path of the application directory
    # @param [String] message an error message with an insert for the reason for failure
    # @yields [Buildpack] the buildpack to work with
    # @return [Object] the return value from the given block
    def self.with_buildpack(app_dir, message)
      app_dir     = Pathname.new(app_dir)
      application = Component::Application.new(app_dir)
      Logging::LoggerFactory.setup application

      yield new(app_dir, application) if block_given?
    rescue => e
      logger = Logging::LoggerFactory.get_logger Buildpack

      logger.error { message % e.inspect }
      logger.debug { "Exception #{e.inspect} backtrace:\n#{e.backtrace.join("\n")}" }
      abort e.message
    end

    # Iterates over all of the components to detect if this buildpack can be used to run an application
    #
    # @return [Array<String>] An array of strings that identify the components and versions that will be used to run
    #                         this application.  If no container can run the application, the array will be empty
    #                         (+[]+).
    def detect
      tags = tag_detection('container', @containers, true)
      tags.concat tag_detection('JRE', @jres, true) unless tags.empty?
      tags.concat tag_detection('framework', @frameworks, false) unless tags.empty?
      tags = tags.flatten.compact

      @logger.debug { "Detection Tags: #{tags}" }
      tags
    end

    # Transforms the application directory such that the JRE, container, and frameworks can run the application
    #
    # @return [void]
    def compile
      component_detection(@jres).first.compile
      component_detection(@frameworks).each { |framework| framework.compile }
      component_detection(@containers).first.compile
    end

    # Generates the payload required to run the application.  The payload format is defined by the
    # {Heroku Buildpack API}[https://devcenter.heroku.com/articles/buildpack-api#buildpack-api].
    #
    # @return [String] The payload required to run the application.
    def release
      component_detection(@jres).first.release
      component_detection(@frameworks).each { |framework| framework.release }
      command = component_detection(@containers).first.release

      payload = {
          'addons'                => [],
          'config_vars'           => {},
          'default_process_types' => { 'web' => command }
      }.to_yaml

      @logger.debug { "Release Payload #{payload}" }

      payload
    end

    private_class_method :new

    private

    def initialize(app_dir, application)
      @logger = Logging::LoggerFactory.get_logger Buildpack

      log_git_info
      log_environment_variables

      additional_libraries = Component::AdditionalLibraries.new app_dir
      mutable_java_home    = Component::MutableJavaHome.new app_dir
      immutable_java_home  = Component::ImmutableJavaHome.new mutable_java_home
      java_opts            = Component::JavaOpts.new app_dir

      components = JavaBuildpack::Util::ConfigurationUtils.load 'components'

      @jres       = instantiate(components['jres'], additional_libraries, application, mutable_java_home, java_opts,
                                app_dir)
      @frameworks = instantiate(components['frameworks'], additional_libraries, application, immutable_java_home,
                                java_opts, app_dir)
      @containers = instantiate(components['containers'], additional_libraries, application, immutable_java_home,
                                java_opts, app_dir)
    end

    def component_detection(components)
      components.select { |component| component.detect }
    end

    def instantiate(components, additional_libraries, application, java_home, java_opts, root)
      components.map do |component|
        @logger.debug { "Instantiating #{component}" }

        require_component(component)

        component_id = component.split('::').last.snake_case
        context      = {
            application:   application,
            component_name: component.split('::').last.space_case,
            configuration: Util::ConfigurationUtils.load(component_id),
            droplet:       Component::Droplet.new(additional_libraries, component_id, java_home, java_opts, root) }

        component.constantize.new(context)
      end
    end

    def git_dir
      Pathname.new(__FILE__).dirname + '../../.git'
    end

    def log_environment_variables
      @logger.debug { "Environment Variables: #{ENV.to_hash}" }
    end

    def log_git_info
      if system("git --git-dir=#{git_dir} status 2>/dev/null 1>/dev/null")
        @logger.debug { "git remotes: #{`git --git-dir=#{git_dir} remote -v`}" }
        @logger.debug { "git HEAD commit: #{`git --git-dir=#{git_dir} log HEAD^!`}" }
      else
        @logger.debug { 'Buildpack is not stored in a git repository' }
      end
    end

    def names(components)
      components.map { |component| component.component_name }.join(', ')
    end

    def require_component(component)
      file = Pathname.new(component.snake_case)

      if file.exist?
        @logger.debug { "Requiring #{file}" }
        require file
      end
    end

    def tag_detection(type, components, unique)
      tags = components.map { |component| component.detect }.compact
      fail "Application can be run by more than one #{type}: #{names components}" if unique && tags.size > 1
      tags
    end

  end

end
