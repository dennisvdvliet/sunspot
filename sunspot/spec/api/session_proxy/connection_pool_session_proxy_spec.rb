require File.expand_path('spec_helper', File.dirname(__FILE__))
require 'weakref'

describe Sunspot::SessionProxy::ConnectionPoolSessionProxy do
  before :each do
    @config = Sunspot::Configuration.build
    @proxy = Sunspot::SessionProxy::ConnectionPoolSessionProxy.new(@config)
    @plain_proxy = Sunspot::SessionProxy::ThreadLocalSessionProxy.new(@config)
  end

  # The following test is disabled by default since it is only meant as
  # proof of concept for this issue. Depending on the processing power of
  # machine the following test should overflow an normal connection with
  # requests. Disabled for performance reasons. If the test fails (eg it
  # does not raise an error) you will need to increase the number of
  # concurrent threads to break your sorl server :-)
  # it 'overflows the solr server with requests' do
  #   threads = []
  #   expect do
  #     10.times do
  #       threads << Thread.new do
  #         10.times do
  #           @plain_proxy.session.index(Post.new(:title => random_text(100), :body => random_text(10000), :id => rand(10000), :published_at => Time.now))
  #           @plain_proxy.commit
  #         end
  #       end
  #     end
  #     threads.each{ |t| t.join}
  #   end.to raise_error
  # end

  # Same number of threads, same number of documents added but this
  # time we use a connection pool. This test is also disabled to make
  # your tests finish quickly. Enable it when needed.

  # it 'uses a connection pool' do
  #   threads = []
  #   10.times do
  #     threads << Thread.new do
  #       10.times do
  #         @proxy.session.index(Post.new(:title => random_text(100), :body => random_text(10000), :id => rand(10000), :published_at => Time.now))
  #         @proxy.commit
  #       end
  #     end
  #   end
  #   threads.each{ |t| t.join}
  # end

  it 'should use one connection per thread' do
    threads = []
    sessions = []
    2.times do
      threads << Thread.new do
        2.times do
          sessions << @plain_proxy.session.to_s
          @plain_proxy.commit
         end
      end
    end
    threads.each{ |t| t.join}
    sessions.uniq.count.should eql(threads.count)
  end

  it 'limit number of connections used to pool size' do
    threads = []
    sessions = []
    5.times do
      threads << Thread.new do
        2.times do
          sessions << @proxy.session.to_s
          @proxy.commit
        end
      end
    end
    threads.each{ |t| t.join}
    sessions.uniq.count.should eql(@config.solr.pool_size)
  end

  (Sunspot::Session.public_instance_methods(false) - ['config', :config]).each do |method|
    it "should delegate #{method.inspect} to its session" do
      args = Array.new(Sunspot::Session.instance_method(method).arity.abs) do
        stub('arg')
      end
      @proxy.session.should_receive(method).with(*args)
      @proxy.send(method, *args)
    end
  end

  it_should_behave_like 'session proxy'
end


def random_text(length = 50)
  (0...length).map{ ('a'..'z').to_a[rand(26)] }.join
end