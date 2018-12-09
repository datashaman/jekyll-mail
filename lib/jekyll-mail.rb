# frozen_string_literal: true

require "rubygems"
require "bundler/setup"

require "dotenv"
require "logger"
require "mail"
require "mail-gpg"
require "oembed"
require "yaml"

env = ENV['JEKYLL_ENV']

files = []

files.push(".env.local") if env != "test"
files.push(".env.#{env}") unless env.nil?
files.push(".env")

Dotenv.load(*files)

$LOG = Logger.new("jekyll-mail.log")

module Jekyll
  module Mail
    class Importer
      DIR_MODE = 0o775
      FILE_MODE = 0o664

      def initialize(site)
        @site = site.chomp

        OEmbed::Providers.register_all
      end

      def extract_images(mail, post_slug)
        post_path = "/posts/#{post_slug}"
        post_dir = "#{@site}#{post_path}"

        FileUtils.mkdir_p(post_dir, :mode => DIR_MODE)

        images = []

        mail.attachments.each do |attachment|
          next unless attachment.content_type.start_with?("image/")

          filename = File.basename(attachment.filename)

          File.open("#{post_dir}/#{filename}", "w+b") do |f|
            f.write attachment.decoded
          end

          File.chmod(FILE_MODE, "#{post_dir}/#{filename}")
          images.push "#{post_path}/#{filename}"
        end

        images
      end

      def extract_body(mail)
        parts = mail.parts

        index = parts.index do |part|
          part.content_type.start_with?("multipart/mixed")
        end

        unless index.nil?
          parts = parts[index].parts
        end

        index = parts.index do |part|
          part.content_type.start_with?("text/plain", "text/html", "text/markdown")
        end

        parts[index].decoded unless index.nil?
      end

      def extract_embed(body)
        match = %r!
          (https?:\/\/)?                  # optional protocol prefix
          (www\.)?                        # optional www prefix
          [-a-zA-Z0-9@:%._\+~#=]{2,256}   # hostname
          \.[a-z]{2,6}                    # domain suffix
          \b([-a-zA-Z0-9@:%_\+.~#?&\/=]*) # optional parameters and anchor
        !x.match(body)

        if match
          resource = OEmbed::Providers.get(match[0])

          unless resource.nil?
            {
              "title" => resource.title,
              "url" => resource.request_url,
              "provider" => {
                "name" => resource.provider_name,
                "url" => resource.provider_url
              },
              "author" => {
                "name" => resource.author_name,
                "url" => resource.author_url,
              },
            }
          end
        end
      end

      def strip_yaml_header(yaml)
        yaml.sub(%r{^---\n}, '')
      end

      def write_post(mail, post_slug, body, images, embed)
        FileUtils.mkdir_p("#{@site}/_posts", :mode => DIR_MODE)
        post_file = "#{@site}/_posts/#{post_slug}.md"

        File.open(post_file, "w") do |f|
          f.write("---\n")
          f.write("layout: post\n")
          f.write("date: #{mail.date.strftime("%F %H:%M:%S %z")}\n")
          f.write("title: #{mail.subject}\n") if mail.subject
          unless images.empty?
            f.write(strip_yaml_header(YAML.dump({'images' => images})))
          end
          unless embed.nil?
            f.write(strip_yaml_header(YAML.dump({'embed' => embed})))
          end
          f.write("---\n")
          f.write("#{body}\n")
        end

        File.chmod(FILE_MODE, post_file)
      end

      def extract_title_slug(mail)
        return mail.subject.downcase.strip.tr(" ", "-").gsub(%r![^\w-]!, "") if mail.subject

        (0...8).map { rand(97..122).chr }.join
      end

      def verify_signature(mail)
        return false if mail.encrypted? or !mail.signed?

        verified = mail.verify
        return false unless verified.signature_valid?

        allowed = ENV['GPG_ALLOWED'].split(',')

        index = verified.signatures.index do |sig|
          allowed.include?(sig.fpr)
        end

        return !index.nil?
      end

      def import(content)
        mail = ::Mail.read_from_string(content)
        return unless mail.multipart? and verify_signature(mail)

        title_slug = extract_title_slug(mail)
        post_slug = "#{mail.date.to_date}-#{title_slug}"

        images = extract_images(mail, post_slug)

        body = extract_body(mail)
        embed = extract_embed(body)

        write_post(mail, post_slug, body, images, embed)
      end
    end
  end
end
