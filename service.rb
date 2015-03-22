#!/usr/bin/env ruby

require 'rubydns'
require 'yaml'

# Use upstream DNS for name resolution.
CONF = YAML.load_file File.expand_path '../conf.yml', __FILE__

HOME_DOMAINS_REGX = /#{File.readlines(File.expand_path '../home_domains.txt', __FILE__).map{ |e| "^(.+\.)?#{e.strip.gsub '.', '\.'}$"  }.join '|'}/

HOME_STREAM = RubyDNS::Resolver.new(CONF[:home_resolvers].map{ |e|
  ip = e.split('#').first.strip
  [:udp, ip, 53]
})
PROXY_STREAM = RubyDNS::Resolver.new [[:udp, '127.0.0.1', 40]]

INTERFACES = [[:udp, '127.0.0.1', 5300], [:tcp, '127.0.0.1', 5300]]

class CustomDnsServer < RubyDNS::RuleBasedServer
  DEBUG = true

  def deliver_to_stream transaction, stream
    if DEBUG
      q = transaction.question.to_s.sub /\.$/, ''
      stream_name = stream.instance_variable_get("@servers").slice(0, 2).to_s

      transaction.passthrough!(stream) { |response|
        logger.info "got #{q} from #{stream_name}"
        response.answer.\
          select{ |name, ttl, res|
            (res.kind_of?(Resolv::DNS::Resource::IN::A) ||
                res.kind_of?(Resolv::DNS::Resource::IN::AAAA)) &&
              ttl > 0
          }.\
          each { |name, ttl, res|
            logger.info "#{q} -> #{res.address.to_s}"
          }
      }
    else
      transaction.passthrough! stream
    end
  end
end

RubyDNS::run_server server_class: CustomDnsServer, listen: INTERFACES do
  logger.level = ::Logger::INFO

  #logger.info HOME_DOMAINS_REGX

  match(HOME_DOMAINS_REGX) { |transaction| deliver_to_stream transaction, HOME_STREAM }

  otherwise { |transaction| deliver_to_stream transaction, PROXY_STREAM }
end

