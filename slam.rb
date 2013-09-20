#!/usr/bin/env ruby

require 'Bundler'
require 'pathname'
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

# add bucket lifecycle policy to transition to glacier "immediately"
bucket = s3.buckets[opts[:bucket]]
bucket.lifecycle_configuration.update do
  #add_rule('backups/', :glacier_transition_time => 0)
end

# setup filesystem listener
listener = Listen.to(opts[:source]) do |modified, added, removed|
  if added
    added.each do |path|
      srcpath = Pathname.new(path)
      putkey  = File.join(opts[:target], srcpath.basename)
      puts srcpath.realpath
      puts putkey
      obj = bucket.objects[putkey].write(:file => srcpath.realpath)
    end
  end
  puts "modified absolute path: #{modified}"
  puts "added absolute path: #{added}"
  puts "removed absolute path: #{removed}"
  # or multipart upload if file is large, i.e. > 100MB
  # obj.write(file, :multipart_threshold => 100 * 1024 * 1024)
  # obj = bucket.objects["backups/test2.txt"].write(:file => "/Users/whiteadr/Development/ice_elemental/test.txt")
end
listener.start
sleep


#bucket.objects.each do |obj|
#  puts obj.key
#end

