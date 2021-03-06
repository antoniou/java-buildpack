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
require 'java_buildpack/container/groovy'

describe JavaBuildpack::Container::Groovy do
  include_context 'component_helper'

  it 'should not detect a non-Groovy project',
     app_fixture: 'container_main' do

    expect(component.detect).to be_nil
  end

  it 'should not detect a .groovy directory',
     app_fixture: 'dot_groovy' do

    expect(component.detect).to be_nil
  end

  it 'should detect a Groovy file with a main() method',
     app_fixture: 'container_groovy_main_method' do

    expect(component.detect).to eq("groovy=#{version}")
  end

  it 'should detect a Groovy file with non-POGO',
     app_fixture: 'container_groovy_non_pogo' do

    expect(component.detect).to eq("groovy=#{version}")
  end

  it 'should not detect a Groovy file with non-POGO and at least one .class file',
     app_fixture: 'container_groovy_non_pogo_with_class_file' do

    expect(component.detect).to be_nil
  end

  it 'should detect a Groovy file with #!',
     app_fixture: 'container_groovy_shebang' do

    expect(component.detect).to eq("groovy=#{version}")
  end

  it 'should detect a Groovy file which has a shebang but which also contains a class',
     app_fixture: 'container_groovy_shebang_containing_class' do

    expect(component.detect).to eq("groovy=#{version}")
  end

  context do
    let(:version) { '2.1.5_10' }

    it 'should fail when a malformed version is detected',
       app_fixture: 'container_groovy_main_method' do

      expect { component.detect }.to raise_error /Malformed version/
    end
  end

  it 'should extract Groovy from a ZIP',
     app_fixture: 'container_groovy_main_method',
     cache_fixture: 'stub-groovy.zip' do

    component.compile

    expect(app_dir + '.groovy/bin/groovy').to exist
  end

  it 'should return command',
     app_fixture: 'container_groovy_main_method' do

    expect(component.release).to eq("JAVA_HOME=#{java_home} JAVA_OPTS=#{java_opts_str} .groovy/bin/groovy " +
                                        '-cp $PWD/.additional-libraries/test-jar-1.jar:' +
                                        '$PWD/.additional-libraries/test-jar-2.jar Application.groovy Alpha.groovy ' +
                                        'directory/Beta.groovy')
  end

  def java_opts_str
    "\"#{java_opts.sort.join(' ')}\""
  end

end
