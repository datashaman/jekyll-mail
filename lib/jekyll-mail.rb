# frozen_string_literal: true

require "rubygems"
require "bundler/setup"

require "dotenv"
require "logger"
require "mail"
require "mail-gpg"
require "oembed"
require "to_slug"
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

      def has_body(part)
        part.content_type.start_with?("text/plain", "text/html", "text/markdown")
      end

      def extract_body_from_parts(parts)
        index = parts.index do |part|
          has_body(part)
        end

        return parts[index] unless index.nil?

        body = nil

        parts.each do |part|
          if part.multipart?
            body = extract_body_from_parts(part.parts)
            break unless body.nil?
          end
        end

        body
      end

      def extract_body(mail)
        decoded = if mail.multipart?
                    body = extract_body_from_parts(mail.parts)
                    body.decoded unless body.nil?
                  else
                    mail.decoded
                    body = ::Mail::Gpg::InlineSignedMessage.strip_inline_signature(decoded)
                    body = body["-----BEGIN PGP SIGNED MESSAGE-----\n\n".length..-1]
                    body[0..-"\n-----END PGP SIGNED MESSAGE-----".length]
                  end
      end

      def extract_embed(body)
        match_url = %r!
        (https?:\/\/)?                  # optional protocol prefix
        (www\.)?                        # optional www prefix
        [-a-zA-Z0-9@:%._\+~#=]{2,256}   # hostname
        \.[a-z]{2,6}                    # domain suffix
        \b([-a-zA-Z0-9@:%_\+.~#?&\/=]*) # optional parameters and anchor
        !x.match(body)

        if match_url
          url = match_url[0]
          match_email = %r{\S+@\S+\.\S+}.match(url)
          return if match_email

          resource = OEmbed::Providers.get(url)

          unless resource.nil?
            {
              "title" => resource.title,
              "url" => resource.request_url,
              "provider_name" => resource.provider_name,
              "provider_url" => resource.provider_url,
              "author_name" => resource.author_name,
              "author_url" => resource.author_url,
              "html" => resource.html,
              "only" => url.strip == body.strip
            }
          end
        end
      end

      def strip_yaml_header(yaml)
        yaml.sub(%r{^---\n}, '')
      end

      def write_post(mail, title, post_slug, body, images, embed)
        FileUtils.mkdir_p("#{@site}/_posts", :mode => DIR_MODE)
        post_file = "#{@site}/_posts/#{post_slug}.md"

        File.open(post_file, "w") do |f|
          f.write("---\n")
          f.write("layout: post\n")
          f.write("date: #{mail.date.strftime("%F %H:%M:%S %z")}\n")
          f.write("title: #{title}\n") unless title.nil?
          f.write(strip_yaml_header(YAML.dump({'images' => images}))) unless images.empty?
          f.write(strip_yaml_header(YAML.dump({'embed' => embed}))) unless embed.nil?
          f.write("---\n")
          f.write("#{body}\n")
        end

        File.chmod(FILE_MODE, post_file)
      end

      def verify_signature(mail)
        $LOG.debug("Encrypted: #{mail.encrypted?}, Signed: #{mail.signed?}")

        return false if mail.encrypted? or !mail.signed?

        verified = mail.verify
        unless verified.signature_valid?
          $LOG.warning("Signature is not valid")
          return false
        end

        allowed = ENV['GPG_ALLOWED'].split(',')

        index = verified.signatures.index do |sig|
          $LOG.debug("Checking #{sig.fpr} against #{allowed.join(',')}")
          allowed.include?(sig.fpr)
        end

        return !index.nil?
      end

      def import(content)
        $LOG.debug("Content #{content}")

        mail = ::Mail.read_from_string(content)
        $LOG.debug("Mail #{mail.inspect}")

        return unless verify_signature(mail)

        body = extract_body(mail)
        $LOG.debug("Body #{body}")

        embed = extract_embed(body)
        $LOG.debug("Embed #{embed.inspect}")

        title = if mail.subject
                  mail.subject
                elsif !embed.nil? and embed['title']
                  embed['title']
                end

        title_slug = if title.nil?
                       (0...8).map { rand(97..122).chr }.join
                     else
                       title.to_slug
                     end

        post_slug = "#{mail.date.to_date}-#{title_slug}"

        images = extract_images(mail, post_slug)

        write_post(mail, title, post_slug, body, images, embed)
      end
    end
  end
end
