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

require 'spec_helper'
require 'component_helper'
require 'java_buildpack/framework/postgresql_jdbc'

describe JavaBuildpack::Framework::PostgresqlJdbc, service_type: 'test-n/a' do
  include_context 'component_helper'

  context do
    let(:vcap_services) { {} }

    it 'should not detect without a postgres service' do
      expect(component.detect).to be_nil
    end

  end

  context do

    let(:service_payload) { [{ 'tags' => %w(postgres relational) }] }

    it 'should detect with postgres service' do
      expect(component.detect).to eq("postgresql-jdbc=#{version}")
    end

    it 'should not detect if the application already has a Postgres driver',
       app_fixture: 'framework_postgresql_jdbc_with_driver' do
      expect(component.detect).not_to be
    end

    it 'should copy the Postgres driver to the lib directory when needed',
       cache_fixture: 'stub-postgresql-0.0-0000-jdbc00.jar' do

      component.compile

      expect(additional_libs_dir + 'postgresql-jdbc-0.0.0.jar').to exist
    end

  end

  context do

    let(:service_payload) { [{ 'tags' => %w(postgresql relational) }] }

    it 'should detect with postgres service' do
      expect(component.detect).to eq("postgresql-jdbc=#{version}")
    end

  end

end
