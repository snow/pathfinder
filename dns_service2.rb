#!/usr/bin/env ruby

################################################
# CAUTION !!!!!!!!!
# this service is only for experiment
# and already abandoned due to poor performance
################################################

require 'rubydns'
#require 'pp'
require 'slop'

OPTS = Slop.parse do |o|
  o.banner = 'Usage: ./dns_service.rb [-d] [-p PORT]'
  o.separator ''
  o.separator 'example:'
  o.separator './dns_service.rb -p 5300'
  o.separator ''
  o.bool '-d', '--debug', 'print debug info'
  o.integer '-p', '--port', 'listen on port, default 5300', default: 5300
  o.on '-h', '--help', 'print help and exit' do
    puts o
    exit
  end
end

INTERFACES = [[:udp, '127.0.0.1', OPTS[:port]], [:tcp, '127.0.0.1', OPTS[:port]]]
CN_NETS = File.open(File.expand_path '../cn_nets.txt', __FILE__).readlines.map{ |ln| IPAddr.new ln.strip }

PROXY_STREAM = RubyDNS::Resolver.pool args: [[[:udp, '127.0.0.1', 40]]]

# sub class to distinguish with ProxyResolver in log
class HomeResolver < RubyDNS::Resolver
  def initialize
    super File.open(File.expand_path '../home_resolvers.txt', __FILE__).readlines.\
      map{ |ln|
        ip = ln.split('#').first.strip
        [:udp, ip, 53]
      }
  end

  def dispatch_request message
    response = super

    if OPTS.debug?
      q = message.question[0][0].to_s.sub /\.$/, ''
    end

    if response.nil?
      @logger.info "got nil response for #{q} from home servers" if OPTS.debug?
    else
      a_records = response.answer.\
        select{ |name, ttl, res| res.kind_of? Resolv::DNS::Resource::IN::A }

      if a_records.any?
        # only consider the first result is OK
        # see http://en.wikipedia.org/wiki/Round-robin_DNS
        ip = a_records.first[2].address.to_s

        CN_NETS.each { |net|
          if net === ip
            # yes it's a home ip
            return response
          end
        }

        @logger.info "got abroad ip #{ip} for #{q} from home server, requery from proxy" if OPTS.debug?

      elsif response.answer.any?
        # got AAAA or PTR or something else
        return response

      else
        @logger.info "got empty answer section for #{q} from home servers" if OPTS.debug?
      end
    end

    PROXY_STREAM.dispatch_request message
  end

  #def valid_response(message, response)
    #if super
      #a_records = response.answer.\
        #select{ |name, ttl, res| res.kind_of? Resolv::DNS::Resource::IN::A }

      #return true if a_records.empty?

      ## only consider the first result is OK
      ## see http://en.wikipedia.org/wiki/Round-robin_DNS
      #ip = a_records.first[2].address.to_s

      #CN_NETS.each { |net| return true if net === ip }

      #puts "got abroad ip #{ip} from home server, abandon result" if DEBUG
      #return false
    #end

    #return false
  #end

  #def to_s
    #super.sub />$/, "[#{@servers.map{ |e| e[1] }.join(', ')}]>"
  #end
end
# use pool to auto recreate dead actor,
# for example, when computer goes sleep, Resolver actor dies for Errno::ENETDOWN
# and leads to Celluloid::DeadActorError without pool
HOME_STREAM = HomeResolver.pool

class CustomServer < RubyDNS::Server
  def initialize *args, &block
    super
    logger.level = ::Logger::INFO
  end

  def process name, resource_class, transaction
    transaction.passthrough! HOME_STREAM
  end
end

RubyDNS::run_server server_class: CustomServer, listen: INTERFACES
