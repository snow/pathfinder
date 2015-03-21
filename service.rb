#!/usr/bin/env ruby

require 'rubydns'
require 'yaml'

# Use upstream DNS for name resolution.
CONF = YAML.load_file File.expand_path '../conf.yml', __FILE__
HOME_STREAM = RubyDNS::Resolver.new(CONF[:home_resolvers].map{ |e|
  ip = e.split('#').first.strip
  [:udp, ip, 53]
})
PROXY_STREAM = RubyDNS::Resolver.new [[:udp, '127.0.0.1', 40]]
INTERFACES = [[:udp, '127.0.0.1', 5300], [:tcp, '127.0.0.1', 5300]]

RubyDNS::run_server listen: INTERFACES do
  #logger.level = ::Logger::INFO

  CONF[:direct_domains].each do |e|
    domain = e.split('#').first.strip

    match(/^(.+\.)?#{domain.gsub '.', '\.'}$/) { |transaction|
      transaction.passthrough! HOME_STREAM
    }
  end

  # ship anything else abroad
  otherwise { |transaction| transaction.passthrough! PROXY_STREAM }
end

