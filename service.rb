#!/usr/bin/env ruby

require 'rubydns'
require 'yaml'

DEBUG = ARGV.select{ |arg| %w(debug -d).include? arg.downcase  }.any?

# Use upstream DNS for name resolution.
CONF = YAML.load_file File.expand_path '../conf.yml', __FILE__

INTERFACES = [[:udp, '127.0.0.1', 5300], [:tcp, '127.0.0.1', 5300]]

class CustomDnsServer < RubyDNS::RuleBasedServer
  def deliver_to_stream transaction, stream_type
    stream = get_stream stream_type

    if DEBUG
      q = transaction.question.to_s.sub /\.$/, ''

      transaction.passthrough!(stream) { |response|
        logger.info "got #{q} from #{stream_type}"
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

  private
  def home_domains_regx
    @home_domains_regx ||= /#{File.readlines(
                                  File.expand_path '../home_domains.txt', __FILE__
                                ).\
                                select{ |e| !e.strip.start_with? '#' }.\
                                map{ |e| e.split('#').first.strip }.\
                                map{ |e| "^(.+\.)?#{e.gsub '.', '\.'}$" }.\
                                join '|'}/
  end

  def get_stream type
    case type
    when :home
      # when computer goes sleep, Resolver actor dies for Errno::ENETDOWN
      # so recreate when it awakes
      # otherwise will see Celluloid::DeadActorError
      @home_stream = nil if @home_stream && !@home_stream.alive?

      @home_stream ||= RubyDNS::Resolver.new(CONF[:home_resolvers].map{ |e|
        ip = e.split('#').first.strip
        [:udp, ip, 53]
      })
    when :proxy
      @proxy_stream = nil if @proxy_stream && !@proxy_stream.alive?

      @proxy_stream ||= RubyDNS::Resolver.new [[:udp, '127.0.0.1', 40]]
    else
      raise 'deliver_to_stream only supports :home and :proxy'
    end
  end
end

RubyDNS::run_server server_class: CustomDnsServer, listen: INTERFACES do
  logger.level = ::Logger::INFO

  match(home_domains_regx) { |transaction| deliver_to_stream transaction, :home }

  otherwise { |transaction| deliver_to_stream transaction, :proxy }
end

