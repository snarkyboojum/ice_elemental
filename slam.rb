#!/usr/bin/env ruby

require 'Bundler'
require 'openssl'
Bundler.require(:default)

opts = Trollop::options do
  opt :bucket, "Select the S3 bucket to archive to",       :short => 'b', :type => String
  opt :source, "Source directory to watch for archival",   :short => 's', :type => String, :default => '.'
  opt :target, "Target directory to write S3 archives to", :short => 't', :type => String, :default => 'backups'
  opt :encryption_key, "RSA asymmetric keypair (AES-256) used to perform client-side encryption/decryption", :short => 'k', :type => String
  opt :list, "List all existing archives", :short => 'l' #default is false?
  opt :verbose, "Verbose output", :short => 'v' # default is false
end

Trollop::die :bucket, "must be given" if not opts[:bucket_given]

s3 = AWS::S3.new(
  :access_key_id => '<access_key_id>',
  :secret_access_key => '<secret_access_key>'
)

# TODO: this check is naive and insufficient
# check for and add a bucket lifecycle policy to transition to glacier "immediately"
bucket = s3.buckets[opts[:bucket]]
if not bucket.lifecycle_configuration.rules
  bucket.lifecycle_configuration.update do
    add_rule(opts[:target], :glacier_transition_time => 0)
  end
end

def compute_key(path, opts)
  srcpath = Pathname.new(path)
  key  = File.join(opts[:target], srcpath.basename)
  return key
end

# setup client side encryption if required
encryption_key = nil
if opts[:encryption_key]
  private_key = File.read(opts[:encryption_key])
  encryption_key = OpenSSL::PKey::RSA.new(private_key)
end

# setup filesystem listener and send new files, modified files, and remove deleted files
listener = Listen.to(opts[:source]) do |modified, added, removed|
  if added
    added.each do |path|
      key = compute_key(path, opts)
      begin
        obj = bucket.objects[key].write(:file => Pathname.new(path).realpath, :encryption_key => encryption_key)
        puts "Added/created object by key: ", key if opts[:verbose]
      rescue Exception => e
        puts "Unhandled error:", e
      end
    end
  end

  if modified
    modified.each do |path|
      key = compute_key(path, opts)
      begin
        obj = bucket.objects[key].write(:file => Pathname.new(path).realpath, :encryption_key => encryption_key)
        puts "Updated object by key: ", key if opts[:verbose]
      rescue Exception => e
        puts "Unhandled error:", e
      end
    end
  end

  if removed
    removed.each do |path|
      key = compute_key(path, opts)
      begin
        obj = bucket.objects[key].delete
        puts "Removed object by key: ", key if opts[:verbose]
      rescue Exception => e
        puts "Unhandled error:", e
      end
    end
  end
end
listener.start
sleep

