class Classroom
  def sanitize
    require 'yaml'
    require 'fileutils'
    require 'puppetclassify'

    puts 'Sanitizing your VM for your next delivery...'

    certname     = `puppet master --configprint certname`.strip
    master       = `puppet agent --configprint server`.strip
    classifier   = "http://#{master}:4433/classifier-api"
    known_groups = [ 'All Nodes', 'Agent-specified environment', 'Production environment', /PE / ]
    known_users  = [ 'admin"=', 'api_user', 'deployer' ]
    auth_info    = {
      'ca_certificate_path' => `puppet master --configprint localcacert`.strip,
      'certificate_path'    => `puppet master --configprint hostcert`.strip,
      'private_key_path'    => `puppet master --configprint hostprivkey`.strip,
    }

    group_pattern  = Regexp.union(known_groups)
    puppetclassify = PuppetClassify.new(classifier, auth_info)
    puppetclassify.groups.get_groups.each do |group|
      next if group['name'].match(group_pattern)
      puppetclassify.groups.delete_group(group['id'])
      print '.'
    end
    puts

    # depends on pltraining/rbac module
    users = YAML.load(`puppet resource rbac_user --to_yaml`)
    users['rbac_user'].each do |user, data|
      next if known_users.include? user
      puts "puppet resource rbac_user #{user} ensure=absent"
      system("puppet resource rbac_user #{user} ensure=absent")
      print '.'
    end
    puts

    `puppet cert list --all --machine-readable`.each_line do |line|
      next unless line.start_with? '+'
      name = line.gsub('"', '').split[1]
      next if name.start_with? 'pe-internal'
      next if name == certname

      system("puppet node deactivate #{name}")
      system("puppet cert clean #{name}")
      print '.'
    end
    puts

    Dir.glob('/home/*').each do |path|
      next if ['/home/training', '/home/showoff'].include? path
      system("userdel #{File.basename(path)}")
      FileUtils.rm_rf path
      print '.'
    end
    puts

    Dir.glob('/etc/puppetlabs/code-staging/environments/*').each do |path|
      next if File.basename(path) == 'production'
      FileUtils.rm_rf path
      print '.'
    end
    puts

    Dir.glob('/etc/puppetlabs/code/environments/*').each do |path|
      next if File.basename(path) == 'production'
      FileUtils.rm_rf path
      print '.'
    end
    puts

    FileUtils.rm_rf('/var/repositories/*')
  end

end
