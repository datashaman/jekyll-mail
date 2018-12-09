# frozen_string_literal: true

require "minitest/autorun"

require "jekyll-mail"
require "mail"
require "timecop"

class MailTest < Minitest::Test
  def setup
    Timecop.freeze(Time.utc(2018, 1, 1, 10, 30))
  end

  def teardown
    Timecop.return
  end

  def test_simple
    mail = Mail.new do
      from "from@example.com"
      to "to@example.com"
      subject "Subject"
      body "Body"
    end

    Dir.mktmpdir do |site|
      Jekyll::Mail::Importer.new(site).import(mail.to_s)
      filename = "#{site}/_posts/2018-01-01-subject.md"
      assert File.exist?(filename)
      assert_equal_filecontent("test/expected/<m>.md", File.read(filename))
    end
  end

  def test_simple_with_image
    mail = Mail.new do
      from "from@example.com"
      to "to@example.com"
      subject "Subject"
      body "Body"
      add_file 'test/fixtures/image.png'
    end

    Dir.mktmpdir do |site|
      Jekyll::Mail::Importer.new(site).import(mail.to_s)
      filename = "#{site}/_posts/2018-01-01-subject.md"
      assert File.exist?(filename)
      assert_equal_filecontent("test/expected/<m>.md", File.read(filename))
    end
  end

  def test_simple_with_images
    mail = Mail.new do
      from "from@example.com"
      to "to@example.com"
      subject "Subject"
      body "Body"
      add_file 'test/fixtures/image.png'
      add_file 'test/fixtures/image.jpeg'
    end

    Dir.mktmpdir do |site|
      Jekyll::Mail::Importer.new(site).import(mail.to_s)
      filename = "#{site}/_posts/2018-01-01-subject.md"
      assert File.exist?(filename)
      assert_equal_filecontent("test/expected/<m>.md", File.read(filename))
    end
  end

  def test_simple_without_subject
    mail = Mail.new do
      from "from@example.com"
      to "to@example.com"
      body "Body"
    end

    Dir.mktmpdir do |site|
      Jekyll::Mail::Importer.new(site).import(mail.to_s)
      files = Dir["#{site}/_posts/*"]
      assert (/2018-01-01-[a-z]{8}/ =~ files[0])
      assert_equal_filecontent("test/expected/<m>.md", File.read(files[0]))
    end
  end

  def test_embed
    mail = Mail.new do
      from "from@example.com"
      to "to@example.com"
      subject "Subject"
      body "Body\n\nhttps://www.youtube.com/watch?v=HxJhYpTIrl8"
    end

    Dir.mktmpdir do |site|
      Jekyll::Mail::Importer.new(site).import(mail.to_s)
      filename = "#{site}/_posts/2018-01-01-subject.md"
      assert File.exist?(filename)
      assert_equal_filecontent("test/expected/<m>.md", File.read(filename))
    end
  end
end
