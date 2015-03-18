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

class Server < RubyDNS::RuleBasedServer
  def initialize *ars, &block
    super

    @cache = {}
  end

  def respond transaction, stream
    addr, expire_at = get_cached transaction

    #logger.warn "#{expire_at}/#{Time.now.to_i}"
    if expire_at && expire_at > Time.now.to_i
      ttl = expire_at - Time.now.to_i
      #logger.warn "respond from cache: #{transaction.question.to_s}, #{get_cached transaction}, #{ttl}"
      transaction.respond! addr, ttl: ttl

    else
      transaction.passthrough!(stream) { |response| cache response }
    end
  end

  def cache response
    response.answer.\
      select{ |name, ttl, res|
        res.kind_of?(Resolv::DNS::Resource::IN::A) && ttl > 0
      }.\
      each { |name, ttl, res|
        # name may be diffrent from response.question when target has CNAME
        key = response.question[0][0].to_s.sub /\.$/, ''
        @cache[key] = [res.address.to_s, Time.now.to_i + ttl]
        #logger.warn CACHE
        return
      }
  end

  def get_cached transaction
    @cache[transaction.question.to_s.sub /\.$/, '']
  end
end

# Start the RubyDNS server
RubyDNS::run_server listen: [[:udp, '127.0.0.1', 53]], server_class: Server do
  CONF[:direct_domains].each do |e|
    domain = e.split('#').first.strip

    match(/^(.+\.)?#{domain.gsub '.', '\.'}$/) { |transaction|
      respond transaction, HOME_STREAM
    }
  end

  # ship anything else abroad
  otherwise { |transaction| respond transaction, PROXY_STREAM }
end

