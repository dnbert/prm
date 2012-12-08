Gem::Specification.new do |s|
	s.name        = 'pack-frm'
	s.version     = '0.0.1'
	s.date        = '2012-12-08'
	s.summary     = "Package Repository Builder"
	s.description = "PRM (Package Repository Manager) is a Package Repository tool"
	s.authors     = ["Brett Gailey"]
	s.email       = 'brett.gailey@dreamhost.com'
	s.files       = ["prm.rb", "prm/repo.rb", "prm/trollop.rb"]
	s.bindir	  = 'bin'
	s.executables = ['prm']
	s.homepage    = 'https://github.com/dnbert/prm'
end
