#!/usr/bin/env ruby

require 'rubydns'
require 'slop'
require 'celluloid/autostart'
require 'sequel'

OPTS = Slop.parse do |o|
  o.banner = 'Usage: ./dns_service.rb [-d] [-p PORT]'
  o.separator ''
  o.separator 'example:'
  o.separator './dns_service.rb -p 5300'
  o.separator ''
  o.bool '-d', '--debug', 'print debug info'
  o.bool '-r', '--review', 'record dns query that sent to proxy for reviewing'
  o.integer '-p', '--port', 'listen on port, default 5300', default: 5300
  o.on '-h', '--help', 'print help and exit' do
    puts o
    exit
  end
end

INTERFACES = [[:udp, '127.0.0.1', OPTS[:port]], [:tcp, '127.0.0.1', OPTS[:port]]]

# sub class to distinguish with ProxyResolver in log
class HomeResolver < RubyDNS::Resolver
  def initialize
    super File.readlines(File.expand_path '../home_resolvers.txt', __FILE__).\
      map{ |ln| ln.split('#').first.strip }.\
      select{ |ln| ln.length >= 7 }.\
      map{ |ln| [:udp, ln, 53] }
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
PROXY_STREAM = ProxyResolver.pool size: 4 * Celluloid.cores

class CustomServer < RubyDNS::Server
  include Celluloid::Notifications

  def initialize *args, &block
    super
    logger.level = ::Logger::INFO

    @home_domains_regx = build_home_domains_regx

    subscribe 'home_domains_updated', :reload_home_domains
  end

  def process name, resource_class, transaction
    if @home_domains_regx.match name
      deliver_to_stream transaction, HOME_STREAM
    else
      deliver_to_stream transaction, PROXY_STREAM, true
    end
  end

  private
  def build_home_domains_regx
    /#{File.readlines(
         File.expand_path '../home_domains.txt', __FILE__
       ).\
       map{ |ln| ln.split('#').first.strip }.\
       select{ |ln| ln.length >= 2 }.\
       map{ |ln| "^(.+\.)?#{ln.gsub '.', '\.'}$" }.\
       join '|'}/
  end

  def reload_home_domains topic
    @home_domains_regx = build_home_domains_regx
  end

  def deliver_to_stream transaction, stream, publish_result = false
    if OPTS.debug?
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

        publish 'dns_result', q, response if OPTS.review? && publish_result
      }
    else
      transaction.passthrough! stream
    end
  rescue IPAddr::InvalidAddressError => err
    logger.error err
    logger.info transaction.question.to_s.sub /\.$/, ''

    # TODO: tell client we have a problem
  end
end

class ResultSubscriber
  include Celluloid
  include Celluloid::Notifications
  include Celluloid::Logger

  DB = Sequel.connect 'sqlite://dns_results.db'
  CN_NETS = File.readlines(File.expand_path '../cn_nets.txt', __FILE__).\
    map{ |ln| IPAddr.new ln.strip }

  def initialize
    subscribe 'dns_result', :on_result

    DB.create_table? :domains do
      primary_key :id
      string :name, null: false, unique: true
      string :status, null: false, default: ''
      index [:name, :status]
    end
  end

  def on_result topic, query, response
    scope = DB[:domains].where(name: query)
    if scope.where('status in ("home", "abroad")').select(1).count > 0
      info "#{query} already reviewed" if OPTS.debug?
      return
    end

    if 0 == scope.select(1).count
      DB[:domains].insert name: query
    end

    response = HOME_STREAM.query query
    if response.nil?
      # can't get result from home resolvers, mark abroad later
    else
      a_records = response.answer.\
        select{ |name, ttl, res| res.kind_of? Resolv::DNS::Resource::IN::A }

      if a_records.any?
        # only consider the first result is OK
        # see http://en.wikipedia.org/wiki/Round-robin_DNS
        ip = IPAddr.new a_records.first[2].address.to_s

        CN_NETS.each { |net|
          if net === ip
            # got home ip from home resolvers
            info "mark #{query} as home" if OPTS.debug?
            scope.update status: 'home'

            # TODO: update home_domains.txt and trigger server reload

            return
          end
        }

        # home resolvers still give abroad ip, mark abroad later

      else
        # don't know what happened, mark abroad later
      end
    end

    info "mark #{query} as abroad" if OPTS.debug?
    scope.update status: 'abroad'
  end
end
result_subscriber = ResultSubscriber.new

RubyDNS::run_server server_class: CustomServer, listen: INTERFACES

#require 'benchmark'
#regx = CustomServer.build_home_domains_regx
## about 0.03 sec
#Benchmark.bmbm do |x|
  #x.report {
    #100.times {
      #regx.match 'cij.cdn.zhihu.com'
    #}
  #}
#end

## about 0.45 sec
#Benchmark.bmbm do |x|
  #x.report {
    #100.times {
      #ip = IPAddr.new '223.255.252.2'
      #CN_NETS.each { |net| net === ip }
    #}
  #}
#end
