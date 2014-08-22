require 'hawser'

describe Hawser do
  it "should create some rake tasks" do
    Hawser::Cluster.new do |cluster|
      cluster.name = "test"
      cluster.user = "testy-mctester"
    end
  end
end
