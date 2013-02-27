Gem::Specification.new do |s|
	s.name        = 'prm'
	s.version     = '0.0.8'
	s.date        = '2013-02-20'
	s.summary     = "Package Repository Manager"
	s.description = "PRM (Package Repository Manager) is an Operating System independent Package Repository tool. PRM supports Repository syncing to DreamObjects"
	s.authors     = ["Brett Gailey"]
	s.email       = 'brett.gailey@dreamhost.com'
	s.files       = [ "lib/prm/repo.rb", "lib/prm/trollop.rb", "lib/prm.rb" ]
	s.bindir	  = 'bin'
	s.executables = ['prm']
	s.add_dependency('peach')
	s.add_dependency('aws-s3')
	s.homepage    = 'https://github.com/dnbert/prm'
end
