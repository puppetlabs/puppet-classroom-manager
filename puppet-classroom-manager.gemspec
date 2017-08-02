$:.unshift File.expand_path("../lib", __FILE__)
require 'date'
require 'classroom/version'

Gem::Specification.new do |s|
  s.name              = "puppet-classroom-manager"
  s.version           = Classroom::VERSION
  s.date              = Date.today.to_s
  s.summary           = "Manage Puppet classroom VMs and updating courseware."
  s.homepage          = "http://github.com/puppetlabs/puppet-classroom-manager"
  s.email             = "education@puppetlabs.com"
  s.authors           = ["Ben Ford"]
  s.license           = "Apache-2.0"
  s.has_rdoc          = false
  s.require_path      = "lib"
  s.executables       = %w( classroom )
  s.files             = %w( README.md LICENSE )
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("bin/**/*")
  s.add_dependency      "aws-sdk"
  s.add_dependency      "puppetclassify"
  s.add_dependency      "serverspec"
  s.add_dependency      "hocon"
  s.add_dependency      "rest-client"

  s.description       = <<-desc
    Manage Puppet classroom VMs and updating courseware. This includes
    troubleshooting and maintenance tasks to be used as needed during
    the delivery and facilities for resetting the VM for use across
    multiple deliveries. This is pre-installed on the classroom VM.

    If you are not teaching Puppet Inc. classes, this is not for you.
  desc
end
