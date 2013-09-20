#!/usr/bin/env ruby

require 'Bundler'
Bundler.require(:default)

opts = Trollop::options do
  opt :bucket, "Select the S3 bucket to archive to",       :short => 'b', :type => String
  opt :source, "Source directory to watch for archival",   :short => 's', :type => String, :default => '.'
  opt :target, "Target directory to write S3 archives to", :short => 't', :type => String, :default => 'backups'
end

Trollop::die :bucket, "must be given" if not opts[:bucket_given]

s3 = AWS::S3.new(
  :access_key_id => 'AKIAIFEXLQPUV4R5K6GQ',
  :secret_access_key => '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'
)

# TODO: this check is naive and insufficient
# check for and add a bucket lifecycle policy to transition to glacier "immediately"
bucket = s3.buckets[opts[:bucket]]
if not bucket.lifecycle_configuration.rules
  bucket.lifecycle_configuration.update do
    add_rule(opts[:target], :glacier_transition_time => 0)
  end
end

# setup filesystem listener and implement "new" files -> S3
listener = Listen.to(opts[:source]) do |modified, added, removed|
  if added
    added.each do |path|
      srcpath = Pathname.new(path)
      putkey  = File.join(opts[:target], srcpath.basename)
      obj = bucket.objects[putkey].write(:file => srcpath.realpath)
    end
  end
end
listener.start
sleep
