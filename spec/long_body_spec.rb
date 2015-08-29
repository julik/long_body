require File.expand_path(File.dirname(__FILE__) + '/spec_helper')
require_relative 'test_download'
require 'retriable'
require_relative 'shared_webserver_examples'

describe "LongBody" do
  SERVERS.each do | server_engine |
    context "on #{server_engine.name}" do
      let(:port) { server_engine.port }
      it_behaves_like "compliant"
    end
  end
end
