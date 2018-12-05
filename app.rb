#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'

require 'mail'
require 'logger'

$LOG = Logger.new('/tmp/app.log')

if ARGV.length != 1
    abort('Please specify the Jekyll site folder as the first parameter')
end

site = ARGV[0].chomp

content = STDIN.read
mail = Mail.read_from_string(content)

title_slug = mail.subject.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
posts_folder = "#{site}/_posts"
post_file = "#{posts_folder}/#{mail.date.to_date.to_s}-#{title_slug}.md"

$LOG.debug("Site: #{site}, Mail: #{mail}, Post file: #{post_file}")

File.open(post_file, 'w', 0664) { |f|
    f.write("---\n")
    f.write("layout: post\n")
    f.write("title: #{mail.subject}\n")
    f.write("---\n")
    f.write(mail.decoded)
}
