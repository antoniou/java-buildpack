# Encoding: utf-8
# Cloud Foundry Java Buildpack
# Copyright (c) 2013 the original author or authors.
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

require 'java_buildpack/logging'
require 'logger'

module JavaBuildpack::Logging

  class DelegatingLogger < ::Logger

    def initialize(klass, delegates)
      @klass     = klass
      @delegates = delegates
    end

    def add(severity, message = nil, progname = nil, &block)
      @delegates.each { |delegate| delegate.add severity, message, @klass, &block }
    end

  end

end
