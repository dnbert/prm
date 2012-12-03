require 'fileutils'
require 'zlib'

module Debian
    def build_apt_repo(path, component, arch, release)
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
        }
    end

    def generate_packages_gz(fpath,pfpath,path,rfpath,r,c,a)
        puts "Generating Packages: #{r} : #{c} : binary-#{a}"

        control_data = ''
        Dir.glob("#{fpath}*.deb") do |deb|
            `ar x #{deb} control.tar.gz` 
            `cat control.tar.gz | tar zxf - ./control`
            control_data << `cat control`
            `rm control.tar.gz`
            `rm control`
        end
       
        d = File.open(pfpath, "w+")
        d.write control_data
        d.write "\n"
        d.close

        data = ''
        f = File.open(pfpath, "r").each { |line|
            data << line
        }
        f.close
        
        Zlib::GzipWriter.open(pfpath + ".gz") do |gz|
            gz.write data
        end
        `apt-ftparchive release #{path}/dists/#{r}/ > #{path}/dists/#{r}/Release`
    end
end

class FRM
    class FRM::Repo
        include Debian

        attr_accessor :path
        attr_accessor :type
        attr_accessor :component
        attr_accessor :arch
        attr_accessor :release

        def create
            parch,pcomponent,prelease = _parse_vars(arch,component,release)

            if "#{@type}" == "deb"
                build_apt_repo(path,pcomponent,parch,prelease)
            elsif "#{@type}" == "rpm"
                # add rpm stuff here
            end
        end

        def _parse_vars(arch_ar,component_ar,release_ar)
            arch_ar = arch.split(",")
            component_ar = component.split(",")
            release_ar = release.split(",")
            return [arch_ar,release_ar,component_ar]
        end
    end
end
