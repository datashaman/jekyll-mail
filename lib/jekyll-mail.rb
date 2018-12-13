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
        embed = extract_embed(body)

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
	$LOG.debug("Slug #{post_slug}")

        images = extract_images(mail, post_slug)
	$LOG.debug("Images #{images}")

        write_post(mail, title, post_slug, body, images, embed)
      end
    end
  end
end
