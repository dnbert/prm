Gem::Specification.new do |s|
	s.name        = 'prm'
	s.version     = '0.0.4'
	s.date        = '2013-01-21'
	s.summary     = "Package Repository Manager"
	s.description = "PRM (Package Repository Manager) is an Operating System independent Package Repository tool. PRM supports Repository syncing to DreamObjects"
	s.authors     = ["Brett Gailey"]
	s.email       = 'brett.gailey@dreamhost.com'
	s.files       = ["prm.rb", "prm/repo.rb", "prm/trollop.rb"]
	s.bindir	  = 'bin'
	s.executables = ['prm']
	s.add_dependency('peach', 'aws/s3')
	s.homepage    = 'https://github.com/dnbert/prm'
end
