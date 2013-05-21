require 'rubygems'
require 'fileutils'
require 'zlib'
require 'digest/md5'
require 'digest/sha2'
require 'erb'
require 'find'
require 'thread'
require 'peach' 
require 'aws/s3'

module Redhat
  def build_rpm_repo(path,arch,release,gpg,silent)
    release.each { |r|
      arch.each { |a|
        orgpath = path
        path = path + "/repodata/"
        FileUtils.mkpath(path)
        timestamp = Time.now.to_i

        template_dir = File.join(File.dirname(__FILE__), "..", "..", "templates")

        erb_files = %w{
          filelists
          other
          primary
        }

        Dir.glob("#{orgpath}/*.rpm").peach do |rpm|
          sha256sum = ''
          sha256_path = "#{orgpath}/sha256_results"
          unless File.directory?(sha256_path)
            FileUtils.mkdir(sha256_path)
          end
          trpm = rpm.split('/').last
          puts rpm
          if File.exists?("#{sha256_path}/#{trpm}")
            file = File.open("#{sha256_path}/#{trpm}", 'r')
            sha256sum = file.read
            file.close
          else
            sha256sum = Digest::SHA256.file(rpm).hexdigest
            puts sha256sum
            File.open("#{sha256_path}/#{trpm}", 'w') { |file| file.write(sha256sum) }
          end

          name = String.new
          rpm_arch = String.new
          version = String.new
          if trpm =~ /^([a-z]+)-(\d+[.]\d+-(?:[a-z]+\+)?\d+)[.](\w+)[.]\w*$/
             name = $1 
             version = $2
             rpm_arch = $3
          end

          package_hash = {
            trpm => {
              "sha256"  => sha256sum,
              "name"    => name,
              "arch"    => rpm_arch,
              "version" => version
            }
          }

          erb_files.each { |f|
            erb = ERB.new(File.open("#{template_dir}/#{f}.xml.erb") { |file|
              file.read
            }).result(binding)

            release_file = File.new("#{path}/#{f}.xml.tmp","wb")
            release_file.puts erb
            release_file.close
          }
        end

        erb_files.each { |f|
          Zlib::GzipWriter.open("#{path}/#{f}.xml.tmp.gz") do |gz|
            f = File.new("#{path}/#{f}.xml.tmp", "r")
            f.each do |line|
              gz.write(line)
            end
          end
        }

        xml_hash = Hash.new()
        xml_hash = {
          "filelists" => {
            "xml"   => "",
            "gz"    => "",
            "size"  => "",
            "osize" => "",
          },
          "other"     => {
            "xml"   => "",
            "gz"    => "",
            "size"  => "",
            "osize" => "",
          },
          "primary"   => {
            "xml"   => "",
            "gz"    => "",
            "size"  => "",
            "osize" => "",
          }
        }

        erb_files.each { |f|
          next if f == "repomd"
          xml_hash[f]["gz"] = Digest::SHA256.file("#{path}/#{f}.xml.tmp.gz").hexdigest
          xml_hash[f]["xml"] = Digest::SHA256.file("#{path}/#{f}.xml.tmp").hexdigest
          xml_hash[f]["size"] = File.size?("#{path}/#{f}.xml.tmp.gz")
          xml_hash[f]["osize"] = File.size?("#{path}/#{f}.xml.tmp")
        }

        erb_two = ERB.new(File.open("#{template_dir}/repomd.xml.erb") { |file|
          file.read
        }).result(binding)

        r_file = File.new("#{path}/repomd.xml.tmp","wb")
        r_file.puts erb_two
        r_file.close

        Dir.glob("#{path}/*.gz") do |f|
          if f =~ /gz$/
            unless f =~ /tmp\.gz$/
              FileUtils.rm(f)
            end
          end
        end

        erb_files.each { |f|
          FileUtils.rm("#{path}/#{f}.xml.tmp")
          FileUtils.move("#{path}/#{f}.xml.tmp.gz", "#{path}/" + xml_hash[f]["gz"] + "-#{f}.xml.gz")
        }
        FileUtils.move("#{path}/repomd.xml.tmp", "#{path}/repomd.xml")
      }
    }
  end
end

module Debian
  def build_apt_repo(path, component, arch, release, gpg, silent)
    release.each { |r|
      component.each { |c|
        arch.each { |a|
          fpath = path + "/dists/" + r + "/" + c + "/" + "binary-" + a + "/"
          pfpath = fpath + "Packages"
          rfpath = fpath + "Release"

          unless silent == true
            puts "Building Path: #{fpath}"
          end

          FileUtils.mkpath(fpath)
          FileUtils.touch(pfpath)
          FileUtils.touch(rfpath)
          generate_packages_gz(fpath,pfpath,path,rfpath,r,c,a, silent)
        }
      }
      generate_release(path,r,component,arch)

      if gpg == true
        generate_release_gpg(path,r)
      end
    }
  end

  def move_packages(path,component,arch,release,directory)
    unless File.exists?(directory)
      puts "ERROR: #{directory} doesn't exist... not doing anything\n"
      return false
    end

    files_moved = Array.new
    release.each { |r|
      component.each { |c|
        arch.each { |a|
            puts a
          Dir.glob(directory + "/*.deb") do |file|
            if file =~ /^.*#{a}.*\.deb$/i || file =~ /^.*all.*\.deb$/i || file =~ /^.*any.*\.deb$/i
              if file =~ /^.*#{r}.*\.deb$/i
                # Lets do this here to help mitigate packages like "asdf-123+wheezy.deb"
                FileUtils.cp(file, "#{path}/dists/#{r}/#{c}/binary-#{a}/")
                FileUtils.rm(file)
              else
                FileUtils.cp(file, "#{path}/dists/#{r}/#{c}/binary-#{a}/")
                files_moved << file
              end
            end
          end
        }
      }
    }

    files_moved.each do |f|
        if File.exists?(f)
            FileUtils.rm(f)
        end
    end
    # Regex?
    #/^.*#{arch}.*\.deb$/i
  end

  def generate_packages_gz(fpath,pfpath,path,rfpath,r,c,a,silent)
    unless silent == true
      puts "Generating Packages: #{r} : #{c} : binary-#{a}"
    end

    npath = "dists/" + r + "/" + c + "/" + "binary-" + a + "/"
    packages_text = []

    d = File.open(pfpath, "w+")	
    write_mutex = Mutex.new

    Dir.glob("#{fpath}*.deb").peach do |deb|
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

      package_info = [
        "Filename: #{npath}#{tdeb}",
        "MD5sum: #{md5sum}",
        "Size: #{init_size}"
      ]

      write_mutex.synchronize do
        # Copy the control file data into the Packages list
        d.write(File.read("tmp/#{tdeb}/control"))
        d.write(package_info.join("\n"))
        d.write("\n") # blank line between package info in the Packages file
      end
    end

    FileUtils.rmtree 'tmp/'

    d.close

    Zlib::GzipWriter.open(pfpath + ".gz") do |gz|
      f = File.new(pfpath, "r")
      f.each do |line|
        gz.write(line)
      end
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


    template_dir = File.join(File.dirname(__FILE__), "..", "..", "templates")
    erb = ERB.new(File.open("#{template_dir}/deb_release.erb") { |file|
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

module SNAP
  def snapshot_to(path,component,release,snapname,type)
    if type != "deb"
      puts "Only deb supported"
      return
    end

    release.each do |r| 
      time = Time.new
      now = time.strftime("%Y-%m-%d-%H-%M")
      new_snap = "#{snapname}-#{now}"

      if File.exists?("#{path}/dists/#{r}/#{snapname}") 
        puts "Snapshot target is a filesystem, remove it or rename your snap target"
        return
      end

      unless File.exists?("#{path}/dists/#{r}/#{new_snap}/")
        Dir.mkdir("#{path}/dists/#{r}/#{new_snap}")
      end

      FileUtils.cp_r(Dir["#{path}/dists/#{r}/#{component}/*"], "#{path}/dists/#{r}/#{new_snap}")
      FileUtils.ln_s "#{new_snap}", "#{path}/dists/#{r}/#{snapname}", :force => true
      puts "Created #{snapname} snapshot of #{component}\n"
    end
  end
end

module DHO
  def sync_to_dho(path, accesskey, secretkey,pcomponent,prelease)
    component = pcomponent.join
    release = prelease.join
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
    puts "Your apt repository is located at http://objects.dreamhost.com/#{path}/"
    puts "Add the following to your apt sources.list"
    puts "deb http://objects.dreamhost.com/#{path}/ #{release} #{component}"
  end
end

module PRM
  class PRM::Repo
    include Debian
    include DHO
    include SNAP
    include Redhat

    attr_accessor :path
    attr_accessor :type
    attr_accessor :component
    attr_accessor :arch
    attr_accessor :release
    attr_accessor :gpg
    attr_accessor :secretkey
    attr_accessor :accesskey
    attr_accessor :snapshot
    attr_accessor :directory

    def create
      if "#{@type}" == "deb"
        parch,pcomponent,prelease = _parse_vars(arch,component,release)
        if snapshot
          snapshot_to(path,pcomponent,prelease,snapshot,type)
        else
          if directory
            silent = true
            build_apt_repo(path,pcomponent,parch,prelease,gpg,silent)
            if move_packages(path,pcomponent,parch,prelease,directory) == false
              return
            end
          end
          silent = false
          build_apt_repo(path,pcomponent,parch,prelease,gpg,silent)
        end
      elsif "#{@type}" == "sync"
        sync_to_dho(path, accesskey, secretkey,pcomponent,prelease)
      elsif "#{@type}" == "rpm"
        component = "test"
        parch,prelease = _parse_vars(arch,component,release)
        silent = false
        build_rpm_repo(path,parch,prelease,gpg,silent)
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
