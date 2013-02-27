#!/usr/bin/env ruby

require 'prm/trollop'
require 'prm/repo'

version_info = "0.0.8"

opts = Trollop::options do
    version "Package Repository Manager #{version_info} - 2012 Brett Gailey"
    opt :type, "Type of repository to create", :type => :string, :required => true, :short => "-t"
    opt :path, "Path to future repository location", :type => :string, :required => true, :short => "-p"
    opt :component, "Component name for repository (Multi component supported by comma)", :type => :string, :required => :true, :short => "-c"
    opt :release, "Release name for repository (Multi release supported by comma)", :type => :string, :required => true, :short => "-r"
    opt :arch, "Architecture for repository (Multi arch supported by comma)", :type => :string, :require => true, :short => "-a"
    opt :gpg, "Sign release files with a GPG key (Expects GPG key to be available)", :default => false
    opt :generate, "Create new repository", :short => "-g"
    opt :accesskey, "Access Key for DreamObjects", :type => :string
    opt :secretkey, "Secret Key for DreamObjects", :type => :string
end

Trollop::die "No arguments" if opts.empty?
Trollop::die "Don't know what to do, maybe --generate?" unless opts[:generate]

r = PRM::Repo.new
r.component = opts[:component]
r.release = opts[:release]
r.arch = opts[:arch]
r.type = opts[:type]
r.path = opts[:path]
r.gpg = opts[:gpg]
r.accesskey = opts[:accesskey]
r.secretkey = opts[:secretkey]

if opts[:generate]
    r.create
end
