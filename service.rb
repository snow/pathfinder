#!/usr/bin/env ruby

require 'rubydns'
require 'yaml'

DEBUG = ARGV.select{ |arg| %w(debug -d).include? arg.downcase  }.any?

# don't rely on the yml conf file, it will be replaced by plain text file soon
CONF = YAML.load_file File.expand_path '../conf.yml', __FILE__

INTERFACES = [[:udp, '127.0.0.1', 5300], [:tcp, '127.0.0.1', 5300]]

HOME_DOMAINS_REGX = /#{File.readlines(
                         File.expand_path '../home_domains.txt', __FILE__
                       ).\
                       select{ |e| !e.strip.start_with? '#' }.\
                       map{ |e| e.split('#').first.strip }.\
                       map{ |e| "^(.+\.)?#{e.gsub '.', '\.'}$" }.\
                       join '|'}/

# sub class to distinguish with ProxyResolver in log
class HomeResolver < RubyDNS::Resolver
  def initialize
    super CONF[:home_resolvers].map{ |e|
      ip = e.split('#').first.strip
      [:udp, ip, 53]
    }
  end

  #def to_s
    #super.sub />$/, "[#{@servers.map{ |e| e[1] }.join(', ')}]>"
  #end
end
# use pool to auto recreate dead actor,
# for example, when computer goes sleep, Resolver actor dies for Errno::ENETDOWN
# and leads to Celluloid::DeadActorError without pool
HOME_STREAM = HomeResolver.pool

class ProxyResolver < RubyDNS::Resolver
  def initialize
    super [[:udp, '127.0.0.1', 40]]
  end

  #def to_s
    #super.sub />$/, "[#{@servers.map{ |e| e[1] }.join(', ')}]>"
  #end
end
PROXY_STREAM = ProxyResolver.pool

class CustomServer < RubyDNS::RuleBasedServer
  def deliver_to_stream transaction, stream
    if DEBUG
      transaction.passthrough!(stream) { |response|
        # response.question may diff from origin when there are CNAME
        q = transaction.question.to_s.sub /\.$/, ''
        logger.info "got #{q} from #{stream}"

        response.answer.\
          select{ |name, ttl, res|
            res.kind_of?(Resolv::DNS::Resource::IN::A) ||
              res.kind_of?(Resolv::DNS::Resource::IN::AAAA)
          }.\
          each{ |name, ttl, res| logger.info "#{q} -> #{res.address.to_s}" }
      }
    else
      transaction.passthrough! stream
    end
  end
end

RubyDNS::run_server server_class: CustomServer, listen: INTERFACES do
  logger.level = ::Logger::INFO

  match(HOME_DOMAINS_REGX) { |transaction| deliver_to_stream transaction, HOME_STREAM }

  otherwise { |transaction| deliver_to_stream transaction, PROXY_STREAM }
end

