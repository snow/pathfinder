#!/usr/bin/env ruby

PATH = File.expand_path '../home_domains.txt', __FILE__
lines = File.open(PATH).readlines.sort
File.open(PATH, 'w+') do |f|
  f.puts lines
end
