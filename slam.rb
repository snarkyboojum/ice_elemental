#!/usr/bin/env ruby

require 'trollop'
require 'AWS'

opts = Trollop::options do
  opt :bucket, "Select the S3 bucket to export to",
      :short => 'b', :type => String
  opt :src, "Source directory to watch for archive import",
      :short => 's', :type => String, :default => '.'
end

Trollop::die :bucket, "must be given" if not opts[:bucket_given]

s3 = AWS::S3.new(
  :access_key_id => 'AKIAIFEXLQPUV4R5K6GQ',
  :secret_access_key => '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'
)

bucket = s3.buckets[opts[:bucket]]

# add bucket lifecycle policy to transition to glacier "immediately"
bucket.lifecycle_configuration.update do
  #add_rule('backups/', :glacier_transition_time => 0)
end

# test writing an object to the backups/ folder
obj = bucket.objects["backups/test2.txt"].write(:file => "/Users/whiteadr/Development/ice_elemental/test.txt")
# or multipart upload if file is large, i.e. > 100MB
#obj.write(file, :multipart_threshold => 100 * 1024 * 1024)

bucket.objects.each do |obj|
  puts obj.key
end
