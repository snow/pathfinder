#!/usr/bin/env ruby

require 'ipaddr'
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
CN_NETS_FILE = File.expand_path '../cn_nets.txt', __FILE__

def parse_cn_nets
  results = []
  prev_net = ''
  File.readlines(CN_NETS_FILE).each do |ln|
    ip = IPAddr.new(ln.strip.sub /\.\d+\.\d+\//, '.0.0/')

    starting_ip = ip.to_s
    unless starting_ip.end_with? '.0.0'
      starting_ip.sub! /\.\d+\.\d+$/, '.0.0'
    end

    unless starting_ip.eql? prev_net
      results << [ip.to_i, ip.instance_variable_get('@mask_addr')]
      prev_net = starting_ip
    end
  end

  %w(127.0.0.1/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 192.168.10.0/8).each { |e|
    ip = IPAddr.new e
    results << [ip.to_i, ip.instance_variable_get('@mask_addr')]
  }

  results.sort{ |x, y| x[0] <=> y[0] }.map{ |e| "[#{e[0]}, #{e[1]}]" }

  #puts "CN ips saved to #{CN_IP_FILE}"
end

CN_IPS = parse_cn_nets.join ",\n#{' ' * 8}"

HOME_DOMAINS = File.readlines(File.expand_path '../home_domains.txt', __FILE__).\
  map{ |ln| "'#{ln.strip}' : 1" }.\
  join ",\n#{' ' * 8}"

PAC_FILE = File.expand_path '../pathfinder.pac', __FILE__
File.open(PAC_FILE, 'w+') do |f|
  f.puts TEMPLATE.gsub('"%home_ip_list%"', CN_IPS).\
    gsub('"%safe_domains%"', HOME_DOMAINS).\
    gsub('%proxy%', OPTS.arguments.first)
end
puts "#{PAC_FILE} generated"
