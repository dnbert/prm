PRM
===

PRM (Package Repository Manager) allows you to quickly build package repositories, inspired by Jordan Sissels' FPM.

Why Use PRM
===

PRM can quickly build and regenerate apt repositories without the need of apt-ftparchive or crazy shell scripts. This allows you to build
apt package repositories on any OS. The goal of PRM is to be able to deploy apt, rpm and solaris packages. Currently only apt repositories are supported
but future releases are expected to contain rpm and solaris updates.

PRM for apt quickly regenerates package repositories by caching md5 hashes and checking against the cache each time Packages.gz is generated. Usually
this is unnecessary, but when there are large packages in a repository this can slow down generation times to 20-30 minutes. PRM proactively md5 caches.


Todo List
===

* Cleanup code [variables, functions, etc]
* Convert md5 caching into JSON
* Enable RPM support
* Enable Solaris support

Install
===
```
gem install prm
```

Commands
===
```
--type, -t <s>:   		Type of repository to create
--path, -p <s>:   		Path to future repository location
--component, -c <s>:   	Component name for repository (Multi component supported by comma)
--release, -r <s>:   	Release name for repository (Multi release supported by comma)
--arch, -a <s>:   		Architecture for repository (Multi arch supported by comma)
--gpg:   				Sign release files with a GPG key (Expects GPG key to be available)
--generate, -g:   		Create new repository
--version, -v:   		Print version and exit
--help, -h:   			Show this message
```

Example
===
```
prm --type deb --path pool --component dev,staging --release precise --arch amd64 --gpg --generate
```
Component, Release and Arch flags can have multiple values seperated by commas.
      end
      safesystem(attributes[:python_bin], "setup.py", "install", *flags)
