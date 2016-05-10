PRM
===

PRM (Package Repository Manager) is an Operating System independent Package Repository tool. It allows you to quickly build Debian and Yum Package Repositories. PRM supports Repository syncing to DreamObjects

Why Use PRM
===

PRM can quickly build and regenerate apt or yum repositories without the need of apt-ftparchive, createrepo or crazy shell scripts. PRM currently has full
functional support for Debian packages and package repository support for RPM packages.

PRM for apt quickly regenerates package repositories by caching md5 hashes and checking against the cache each time Packages.gz is generated. Usually
this is unnecessary, but when there are large packages in a repository this can slow down generation times to 20-30 minutes. PRM proactively md5 caches.

The --directory (-d) flag can be used to move packages from a directory into your package repository. PRM will look through the location passed into
the -d flag and move any matching packages into their respective location. Packages are moved based on their architecture (amd64, i386, etc). 

Alternatively, you may choose to place your packages into path/dists/release/component/arch/.

Syncing
===

PRM supports syncing your Debian and Ubuntu repositories to S3 compatible object stores such as AWS S3 and DreamObjects

```
prm -t sync -p pool -r squeeze -a amd64 -c main -g --accesskey my_access_key --secretkey my_secret_key -u objects.dreamhost.com
```

Buckets are created based on the path (-p) flag. In the previous case, pool would be a bucket and the contents of your repository would be objects. If the 
bucket does not exist, PRM will create it for you.

To use your S3 bucket as your apt repository, add the following to your sources.list

```
deb http://objects.dreamhost.com/my_bucket_name/ my_release my_component
```

If the local apt repository has packages removed, PRM will remove these from your bucket. All objects synced are set by default to be public.

Snapshots
===

Snapshots can be used to promote components within Debian package repositories. The components are named [snapshot-name]-[date] and is symlinked to [snapshot-name].

```
prm -t deb -p pool -r precise -a amd64 -c unstable -s stable -g
```

The --recent option will only move packages based on their name and their last mtime. For example, if you have a package named openstack-keystone with versions 1.2, 1.3 and 1.4 then only the last modified time of that package will be moved. So if openstack-keystone_1.3_amd64.deb was the last modified, then the --recent flag will move that package only (1.2 and 1.4 will be left alone). This option is useful for organizations wanting to snapshot branching of collaborative software together and run test suits on it or make it a stable deployment component.

Omnibus
===
An Omnibus package is available here https://github.com/rlangford/omnibus-prm
Many thanks to rlangford!

Todo List
===

* Cleanup code [variables, functions, etc]
* Convert md5 caching into JSON
* Enable Solaris support
* Add RPM support for Sync/Snapshot features

Install
===
```
gem install prm
```

Commands
===
```
Usage:
prm [OPTIONS]

Options:
-t, --type TYPE               Type of repo to create
-p, --path PATH               Path to repo location
-r, --release RELEASE         OS version to create
-a, --arch ARCH               Architecture of repo contents
-c, --component COMPONENT     Component to create [DEB ONLY]
-l, --label LABEL             Label for generated repository [DEB ONLY]
-o, --origin ORIGIN           Origin for generated repository [DEB ONLY]
-u, --upload UPLOAD           Upload your repository to a S3 compatible object store [DEB ONLY]
--nocache                     Don't cache md5 sums [DEB ONLY]
--accesskey ACCESS KEY        DHO/S3 Access Key (default: false)
--secretkey SECRET KEY        DHO/S3 Secret Key (default: false)
-d, --directory DIRECTORY     Move packages from directory to target (default: false)
-s, --snapshot COMPONENT      Creates a snapshot of a component (default: false)
-e, --recent                  Snapshot the most recent unique packages (default: false)
-g, --generate                [DEPRECATED 0.2.4]
-k, --gpg GPG KEY             Sign release files with this GPG key (default: false)
-x, --gpg_passphrase          Provide GPG passphrase to prevent prompt by GPG (default: false)
-n, --gpg_sign_algorithm      Provide GPG hash digest signing algorithm (default: false)
-h, --help                    print help
```

Example
===
```
prm --type deb --path pool --component dev,staging --release precise --arch amd64 --gpg

prm -t deb -p pool -c stable -r precise -a amd64 --directory unstable

prm -t deb -p pool -c stable -r precise -a amd64 --directory unstable --gpg user@domain.com --gpg_password myPa55word

prm -t rpm -a x86_64 -r centos6 -p pool
```
