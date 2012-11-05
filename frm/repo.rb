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
                    generate_packages_gz(pfpath,path,rfpath,r,c,a)
                }
            }
        }
    end

    def generate_packages_gz(pfpath,path,rfpath,r,c,a)
        puts "Generating Packages: #{r} : #{c} : binary-#{a}"
        `apt-ftparchive packages #{path} > #{pfpath}`
        puts "Generating Release: #{r}"
        `apt-ftparchive release #{path}/dists/#{r}/ > #{path}/dists/#{r}/Release`
        #data = ''
        #f = File.open(pfpath, "r").each { |line|
        #    data << line
        #}
        #f.close
        #
        #Zlib::GzipWriter.open(pfpath + ".gz") do |gz|
        #    gz.write data
        #end
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
