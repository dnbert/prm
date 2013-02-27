require 'rubygems'
require 'fileutils'
require 'zlib'
require 'digest/md5'
require 'peach' 
require 'erb'
require 'find'
require 'aws/s3'

module Debian
    def build_apt_repo(path, component, arch, release, gpg)
        release.each { |r|
            component.each { |c|
                arch.each { |a|
                    fpath = path + "/dists/" + r + "/" + c + "/" + "binary-" + a + "/"
                    pfpath = fpath + "Packages"
                    rfpath = fpath + "Release"

                    puts "Building Path: #{fpath}"

                    FileUtils.mkpath(fpath)
                    FileUtils.touch(pfpath)
                    FileUtils.touch(rfpath)
                    generate_packages_gz(fpath,pfpath,path,rfpath,r,c,a)
                }
            }
            generate_release(path,r,component,arch)

            if gpg == true
                generate_release_gpg(path,r)
            end
        }
    end

    def generate_packages_gz(fpath,pfpath,path,rfpath,r,c,a)
        puts "Generating Packages: #{r} : #{c} : binary-#{a}"

        d = File.open(pfpath, "w+")	
        npath = "dists/" + r + "/" + c + "/" + "binary-" + a + "/"
        control_data = []

        Dir.glob("#{fpath}*.deb").peach do |deb|
            temp_control = ''
            md5sum = ''
            tdeb = deb.split('/').last
            md5sum_path = path + "/dists/" + r + "/" + c + "/" + "binary-" + a + "/md5-results/" + tdeb

            FileUtils.mkdir_p "tmp/#{tdeb}/"
            FileUtils.mkdir_p path + "/dists/" + r + "/" + c + "/" + "binary-" + a + "/md5-results/"
            `ar p #{deb} control.tar.gz | tar zx -C tmp/#{tdeb}/`

            init_size = `wc -c < #{deb}`

            if File.exists? md5sum_path
                file = File.open(md5sum_path, 'r')
                md5sum = file.read
                file.close
            else
                md5sum = Digest::MD5.file(deb)
                File.open(md5sum_path, 'w') { |file| file.write(md5sum) }
            end


            `echo "Filename: #{npath}#{tdeb}" >> tmp/#{tdeb}/control`
            `echo "MD5sum: #{md5sum}" >> tmp/#{tdeb}/control`
            `echo "Size: #{init_size}" >> tmp/#{tdeb}/control`
            temp_control << `cat tmp/#{tdeb}/control`
            control_data << temp_control
        end

        FileUtils.rmtree 'tmp/'

        d.write control_data
        d.close

        data = ''
        f = File.open(pfpath, "r").each { |line|
            data << line
        }
        f.close

        Zlib::GzipWriter.open(pfpath + ".gz") do |gz|
            gz.write data
        end
    end

    def generate_release(path,release,component,arch)
        date = Time.now.utc

        release_info = Hash.new()
        unreasonable_array = Array.new
        unreasonable_array = ["Packages", "Packages.gz", "Release"]

        component.clear

        Dir.glob(path + "/dists/" + release + "/*").select { |f|
            f.slice!(path + "/dists/" + release + "/")
            unless f == "Release" or f == "Release.gpg"
                component << f
            end
        }

        component.each do |c| 
            arch.each do |ar|
                unreasonable_array.each do |unr|
                    tmp_path = "#{path}/dists/#{release}/#{c}/binary-#{ar}"
                    tmp_hash = Hash.new
                    filename = "#{c}/binary-#{ar}/#{unr}".chomp

                    byte_size = File.size("#{tmp_path}/#{unr}").to_s
                    md5sum = Digest::MD5.file("#{tmp_path}/#{unr}").to_s

                    tmp_hash['size'] = byte_size
                    tmp_hash['md5sum'] = md5sum
                    release_info[filename] = tmp_hash
                end
            end
        end

        erb = ERB.new(File.open('templates/deb_release.erb') { |file|
            file.read
        }).result(binding)

        release_file = File.new("#{path}/dists/#{release}/Release.tmp","wb")
        release_file.puts erb
        release_file.close

        FileUtils.move("#{path}/dists/#{release}/Release.tmp", "#{path}/dists/#{release}/Release")
    end

    # We expect that GPG is installed and a key has already been made
    def generate_release_gpg(path,release)
        Dir.chdir("#{path}/dists/#{release}") do
            system "gpg --yes --output Release.gpg -b Release"
        end
    end
end

module DHO
    def sync_to_dho(path, accesskey, secretkey)
        AWS::S3::Base.establish_connection!(
            :server             => 'objects.dreamhost.com',
            :use_ssl            => true,
            :access_key_id      => accesskey,
            :secret_access_key  => secretkey
        )
        
        AWS::S3::Service.buckets.each do |bucket|
            unless bucket == path
                AWS::S3::Bucket.create(path)
            end
        end

        new_content = Array.new
        Find.find(path + "/") do |object|
            object.slice!(path + "/")
            if (object =~ /deb$/) || (object =~ /Release$/) || (object =~ /Packages.gz$/) || (object =~ /Packages$/) || (object =~ /gpg$/)
                f = path + "/" + object
                new_content << object
                AWS::S3::S3Object.store(
                    object,
                    open(f),
                    path
                )

                policy = AWS::S3::S3Object.acl(object, path)
                policy.grants = [ AWS::S3::ACL::Grant.grant(:public_read) ]
                AWS::S3::S3Object.acl(object,path,policy)
            end
        end

        bucket_info = AWS::S3::Bucket.find(path)
        bucket_info.each do |obj|
            o = obj.key
            if (o =~ /deb$/) || (o =~ /Release$/) || (o =~ /Packages.gz$/) || (o =~ /Packages$/) || (o =~ /gpg$/)
                unless new_content.include?(o)
                    AWS::S3::S3Object.delete(o,path)
                end
            end
        end
    end
end

module PRM
    class PRM::Repo
        include Debian
        include DHO

        attr_accessor :path
        attr_accessor :type
        attr_accessor :component
        attr_accessor :arch
        attr_accessor :release
        attr_accessor :gpg
        attr_accessor :secretkey
        attr_accessor :accesskey

        def create
            parch,pcomponent,prelease = _parse_vars(arch,component,release)

            if "#{@type}" == "deb"
                build_apt_repo(path,pcomponent,parch,prelease,gpg)
            elsif "#{@type}" == "sync"
                sync_to_dho(path, accesskey, secretkey)
            elsif "#{@type}" == "rpm"
                # add rpm stuff here
            end
        end

        def _parse_vars(arch_ar,component_ar,release_ar)
            arch_ar = arch.split(",")
            component_ar = component.split(",")
            release_ar = release.split(",")
            return [arch_ar,component_ar,release_ar]
        end
    end
end
