# frozen_string_literal: true

require "rubygems"
require "bundler/setup"

require "mail"
require "oembed"

module Jekyll
  module Mail
    class Importer
      DIR_MODE = 0o775
      FILE_MODE = 0o664

      def initialize(site)
        @site = site.chomp

        OEmbed::Providers.register_all
      end

      def extract_images(attachments, post_dir)
        images = []

        attachments.each do |attachment|
          next unless attachment.content_type.start_with?("image/")

          filename = File.basename(attachment.filename)

          begin
            File.open("#{post_dir}/#{filename}", "w+b") do |f|
              f.write attachment.decoded
            end
            File.chmod(FILE_MODE, "#{post_dir}/#{filename}")
            images.push "#{post_path}/#{filename}"
          rescue StandardError => e
            Jekyll.logger.error("Unable to save data for #{filename}: #{e.message}")
          end
        end

        images
      end

      def extract_body(mail)
        if mail.multipart?
          index = mail.parts.index do |part|
            part.content_type.start_with?("text/plain", "text/html", "text/markdown")
          end

          mail.parts[index] unless index.nil?
        else
          mail.decoded
        end
      end

      def extract_embed(body)
        match = %r!
          (https?:\/\/)?                  # optional protocol
          (www\.)?                        # optional www prefix
          [-a-zA-Z0-9@:%._\+~#=]{2,256}   # hostname
          \.[a-z]{2,6}                    # domain suffix
          \b([-a-zA-Z0-9@:%_\+.~#?&\/=]*) # option query parameters
        !x.match(body)

        if match
          resource = OEmbed::Providers.get(match[0])

          if resource
            "## <a href=\"#{resource.provider_url}\">#{resource.provider_name}</a>" \
            "<a href=\"#{resource.author_url}\">#{resource.author_name}</a>\n" \
            "### <a href=\"#{resource.request_url}\">#{resource.title}</a>\n" \
            "#{resource.html}"
          end
        end
      end

      def write_post(mail, post_slug, body, images)
        FileUtils.mkdir_p("#{@site}/_posts", :mode => DIR_MODE)
        post_file = "#{@site}/_posts/#{post_slug}.md"

        File.open(post_file, "w") do |f|
          f.write("---\n")
          f.write("layout: post\n")
          f.write("date: #{mail.date.strftime("%F %H:%M:%S %z")}\n")
          f.write("title: #{mail.subject}\n")
          unless images.empty?
            f.write("images:\n")
            images.each do |image|
              f.write("- #{image}\n")
            end
          end
          f.write("---\n")
          f.write("#{body}\n")
        end

        File.chmod(FILE_MODE, post_file)
      end

      def extract_title_slug(mail)
        if mail.subject
          subject = mail.subject
          return subject.downcase.strip.tr(" ", "-").gsub(%r![^\w-]!, "")
        end

        (0...8).map { rand(97..123).chr }.join
      end

      def import(content)
        mail = ::Mail.read_from_string(content)

        title_slug = extract_title_slug(mail)
        post_slug = "#{mail.date.to_date}-#{title_slug}"
        post_path = "/posts/#{post_slug}"
        post_dir = "#{@site}#{post_path}"
        FileUtils.mkdir_p(post_dir, :mode => DIR_MODE)

        images = extract_images(mail.attachments, post_path)
        body = extract_body(mail)
        embed = extract_embed(body)
        body += "\n\n#{embed}" unless embed.nil?

        write_post(mail, post_slug, body, images)
      end
    end
  end
end
