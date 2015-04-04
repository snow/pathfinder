#!/usr/bin/env ruby

require 'slop'
OPTS = Slop.parse do |o|
  o.banner = 'Usage: ./generate_pac.rb [-f] PROXY'
  o.separator ''
  o.separator 'example:'
  o.separator './generate_pac.rb -f PROXY 127.0.0.1:8964; SOCKS 127.0.0.1:1080'
  o.separator ''
  o.bool '-f', '--force_fetch', 'Fetch CN ips even cache exists'
end
if OPTS.arguments.empty?
  puts OPTS
  exit
end

TEMPLATE = File.open(File.expand_path '../pac_template.js', __FILE__).read
CN_IP_FILE = File.expand_path '../cn_ips.txt', __FILE__

IP_RECORDS_URL = 'http://ftp.apnic.net/apnic/stats/apnic/delegated-apnic-latest'
CN_REGX = /apnic\|cn\|ipv4\|[0-9\.]+\|[0-9]+\|[0-9]+\|a.*/i

def fetch_cn_ips
  require 'open-uri'
  require 'ipaddr'

  results = []
  prev_net = ''
  #CN_RECORDS = File.open(File.expand_path '../delegated-apnic-latest', __FILE__).read.scan CN_REGX
  puts "fetching #{IP_RECORDS_URL}"
  open(IP_RECORDS_URL){ |f| f.read }.tap{
    puts "parsing..."
  }.scan(CN_REGX).each do |record|
    cols = record.split '|' # => apnic|CN|ipv4|1.50.0.0|65536|20100902|allocated
    starting_ip = cols[3]
    ips_count = cols[4].to_i

    # TODO: maybe there are better approch in ruby?
    imask = (0xffffffff ^ (ips_count - 1)).to_s 16
    mask = "#{imask[0..1].hex}.#{imask[2..3].hex}.0.0"

    # mask in *nix format
    # it's not used for now
    mask2 = 32 - Math.log(ips_count, 2).to_i

    unless starting_ip.end_with? '.0.0'
      starting_ip.sub! /\.\d+\.\d+$/, '.0.0'
    end

    unless starting_ip.eql? prev_net
      results << [IPAddr.new(starting_ip).to_i, IPAddr.new(mask).to_i, mask2]
      prev_net = starting_ip
    end
  end

  results << [IPAddr.new('127.0.0.1').to_i, IPAddr.new('255.0.0.0').to_i, 0]
  results << [IPAddr.new('10.0.0.0').to_i, IPAddr.new('255.0.0.0').to_i, 0]
  results << [IPAddr.new('172.16.0.0').to_i, IPAddr.new('255.240.0.0').to_i, 0]
  results << [IPAddr.new('192.168.0.0').to_i, IPAddr.new('255.255.0.0').to_i, 0]

  results.sort!{ |x, y| x[0] <=> y[0] }

  File.open(CN_IP_FILE, 'w+') do |f|
    results.each { |e|
      f.puts "[#{e[0]}, #{e[1]}]"
    }
  end

  puts "CN ips saved to #{CN_IP_FILE}"
end

if OPTS.force_fetch? || !File.exists?(CN_IP_FILE)
  fetch_cn_ips
end
CN_IPS = File.open(CN_IP_FILE).readlines.\
  map{ |ln| ln.strip }.\
  join ",\n#{' ' * 8}"

HOME_DOMAINS = File.open(File.expand_path '../home_domains.txt', __FILE__).readlines.\
  map{ |ln| "'#{ln.strip}' : 1" }.\
  join ",\n#{' ' * 8}"

PAC_FILE = File.expand_path '../pathfinder.pac', __FILE__
File.open(PAC_FILE, 'w+') do |f|
  f.puts TEMPLATE.gsub('"%home_ip_list%"', CN_IPS).\
    gsub('"%safe_domains%"', HOME_DOMAINS).\
    gsub('%proxy%', OPTS.arguments.first)
end
puts "#{PAC_FILE} generated"
