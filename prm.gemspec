Gem::Specification.new do |s|
  s.name        = 'prm'
  s.version     = '0.1.2'
  s.date        = '2013-05-11'
  s.summary     = "Package Repository Manager"
  s.description = "PRM (Package Repository Manager) is an Operating System independent Package Repository tool. PRM supports Repository syncing to DreamObjects"
  s.authors     = ["Brett Gailey"]
  s.email       = 'brett.gailey@dreamhost.com'
  s.files       = [ "lib/prm/repo.rb", "lib/prm.rb", "templates/deb_release.erb" ]
  s.bindir	  = 'bin'
  s.executables = ['prm']
  s.add_dependency('peach')
  s.add_dependency('aws-s3')
  s.add_dependency('clamp')
  s.add_dependency('arr-pm')
  s.homepage    = 'https://github.com/dnbert/prm'
end
