require 'rubygems'
require 'bundler/setup'

require 'mail'
require 'oembed'

module Jekyll
  module Mail
    class Importer
      DIR_MODE = 0775
      FILE_MODE = 0664

      def initialize(site)
        @site = site.chomp

        OEmbed::Providers.register_all
      end

      def import(content)
        mail = ::Mail.read_from_string(content)

        if mail.subject
          subject = mail.subject
          title_slug = subject.downcase.strip.gsub(' ', '-').gsub(/[^\w-]/, '')
        else
          title_slug = (0...8).map { (97 + rand(26)).chr }.join
        end

        post_slug = "#{mail.date.to_date.to_s}-#{title_slug}"

        post_path = "/posts/#{post_slug}"
        post_dir = "#{@site}#{post_path}"

        FileUtils.mkdir_p(post_dir, :mode => DIR_MODE)

        images = []

        mail.attachments.each do |attachment|
          if attachment.content_type.start_with?('image/')
            filename = File.basename(attachment.filename)

            begin
              File.open("#{post_dir}/#{filename}", 'w+b') { |f|
                f.write attachment.decoded
              }
              File.chmod(FILE_MODE, "#{post_dir}/#{filename}")
              images.push "#{post_path}/#{filename}"
            rescue => e
              puts "Unable to save data for #{filename}: #{e.message}"
            end
          end
        end

        if mail.multipart?
          for part in mail.parts
            if part.content_type.start_with?('text/plain', 'text/html', 'text/markdown')
              body = part.decoded
              break
            end
          end
        else
          body = mail.decoded
        end

        match = /(https?:\/\/)?(www\.)?[-a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&\/=]*)/.match(body)

        if match
          resource = OEmbed::Providers.get(match[0])

          if resource
            body += "\n\n
                ## <a href=\"#{resource.provider_url}\">#{resource.provider_name}</a> <a href=\"#{resource.author_url}\">#{resource.author_name}</a>
                ### <a href=\"#{resource.request_url}\">#{resource.title}</a>
            #{resource.html}"
          end
        end

        FileUtils.mkdir_p("#{@site}/_posts", :mode => DIR_MODE)
        post_file = "#{@site}/_posts/#{post_slug}.md"

        File.open(post_file, 'w') { |f|
          f.write("---\n")
          f.write("layout: post\n")
          f.write("date: #{mail.date.strftime('%F %H:%M:%S %z')}\n")
          f.write("title: #{mail.subject}\n")
          unless images.empty?
            f.write("images:\n")
            for image in images
              f.write("- #{image}\n")
            end
          end
          f.write("---\n")
          f.write("#{body}\n")
        }

        File.chmod(FILE_MODE, post_file)
      end
    end
  end
end
