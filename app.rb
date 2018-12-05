#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'mail'
require 'logger'

$LOG = Logger.new('/tmp/app.log')

if ARGV.length != 1
    abort('Please specify the Jekyll site folder as the first parameter')
end

site = ARGV[0]

content = STDIN.read
mail = Mail.read_from_string(content)

$LOG.debug("Site: #{site}, Mail: #{mail}")
