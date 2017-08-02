class Classroom
  def troubleshoot
    master   = `puppet agent --configprint server`.strip
    codedir  = `puppet master --configprint codedir`.strip
    filesync = '/etc/puppetlabs/puppetserver/conf.d/file-sync.conf'
    release  = File.read('/etc/puppetlabs-release').to_f rescue 0
    legacy   = release < 7.0

    if File.exist? filesync
      # why isn't there a configprint setting for this?
      staging = `hocon -f #{filesync} get file-sync.repos.puppet-code.staging-dir`.strip
      puts "Running checks for Code Manager configurations:"
    else
      staging = codedir
      puts "Running checks for configurations without Code Manager:"
    end

    print "Cleaning any stray .git directories in: #{codedir}..."
    sleep 1
    system("find #{codedir} -name .git -type d -print -exec rm -rf {} \\;")
    check_success

    print "Validating permissions on: #{codedir}..."
    sleep 1
    system("find #{codedir} '!' -user pe-puppet -print -exec chown pe-puppet:pe-puppet {} \\;")
    check_success

    if codedir != staging
      puts "Validating permissions on: #{staging}..."
      sleep 1
      system("find #{staging} '!' -user pe-puppet -print -exec chown pe-puppet:pe-puppet {} \\;")
      check_success
    end

    # only check legacy systems that rely on manual installs
    if legacy
      if File.exist? '/home/training/courseware'
        print "Sanitizing uploaded courseware..."
        sleep 1
        FileUtils.rm_f '/home/training/courseware/stats/viewstats.json'
        FileUtils.rm_f '/home/training/courseware/stats/forms.json'
        check_success
      else
        check_success(false)
        puts "\tYou don't seem to have uploaded the courseware from your host system"
      end
    end

    print "Checking Forge connection..."
    if system("ping -c1 -W2 forge.puppet.com >/dev/null 2>&1")
      if legacy
        puts "Ensuring the latest version of pltraining/classroom in #{staging}..."
        system("puppet module upgrade pltraining/classroom --modulepath #{staging}")
        check_success
      else
        check_success(true)
      end
    else
      if `awk '$1 == "server" {print $2}' /etc/ntp.conf` != master
        check_success(false)
        puts "\tCould not reach the Forge. You should classify your master as $offline => true"
      else
        puts "\tYou appear to be in offline mode."
      end
    end

    if codedir != staging
      print "Ensuring you have a valid deploy token..."
      if File.exist? '/root/.puppetlabs/token'
        token  = `puppet access show`
        api    = 'https://#{master}:4433/rbac-api/v1/users/current'
        status = `curl -k --write-out "%{http_code}" --silent --output /dev/null #{api} -H "X-Authentication:#{token}"`.strip
        if status != "200"
          print "\nRegenerating invalid token..."
          FileUtils.rm_f('/root/.puppetlabs/token')
          check_success
        end
      end

      unless File.exist? '/root/.puppetlabs/token'
        print "\nGenerating new token."
        system('puppet plugin download > /dev/null')
        system('puppet resource rbac_user deployer ensure=present display_name=deployer email=deployer@puppetlabs.vm password=puppetlabs roles=4 > /dev/null')
        system('echo "puppetlabs" | HOME=/root /opt/puppetlabs/bin/puppet-access login deployer --lifetime 14d > /dev/null')
        check_success
      else
        check_success(true)
      end

      puts
      puts "If you're having trouble with Code Manager or FileSync, deleting all deployed"
      puts "code and destroying all caches can sometimes help you get going again."
      puts
      if confirm?('Would you like to nuke it all and start over?', false)
        reset([:filesync])
      end
    end

    print "Validating SSL certificates..."
    if valid_certificates
      check_success(true)
    else
      puts
      puts "It looks like there is an inconsistency with your master's SSL certificates."
      puts "Regenerating certificates may take up to five minutes."
      puts
      if confirm?('Would you like to try regenerating certificates?', false)
        reset([:certificates])
      end
    end

    puts
    puts 'Done checking. Fix any errors noted above and try again.'
    puts 'If still having troubles, try some of the following steps.'
    puts 'Note that both tail and journalctl have a "-f" follow mode.'
    puts
    puts 'Log files:'
    puts '  * tail /var/log/puppetlabs/puppetserver/puppetserver.log'
    puts '  * tail /var/log/puppetlabs/console-services/console-services.log'
    puts '  * tail any other interesting log files in /var/log/puppetlabs'
    puts 'System logs:'
    puts '  * journalctl -eu pe-puppetserver'
    puts '  * journalctl -eu pe-console-services'
    puts '  * systemctl list-units | egrep "pe-|puppet"'
    puts 'Edu tools:'
    puts '  * tail /var/log/puppetfactory'
    puts '  * journalctl -eu abalone'
    puts '  * journalctl -eu puppetfactory'
    puts '  * journalctl -eu showoff-courseware'
    puts '  * reset_ssl_certificates.sh'
    puts '  * restart_classroom_services.rb'
    puts '  * dependency_nuke.rb'
    puts
    puts 'Have you searched the Troubleshooting Guide for your issue?'
    puts "If you're still stuck, page the on-call support with 'classroom page'"
  end

  def valid_certificates
    certname      = `puppet master --configprint certname`.strip
    ssldir        = '/etc/puppetlabs/puppet/ssl'
    puppetdbcerts = '/etc/puppetlabs/puppetdb/ssl'
    consolecerts  = '/opt/puppetlabs/server/data/console-services/certs'
    pgsqlcerts    = '/opt/puppetlabs/server/data/postgresql/9.4/data/certs'
    orchcerts     = '/etc/puppetlabs/orchestration-services/ssl'

    cert = same_file("#{ssldir}/certs/#{certname}.pem", [
                                                          "#{puppetdbcerts}/#{certname}.cert.pem",
                                                          "#{pgsqlcerts}/_local.cert.pem",
                                                          "#{consolecerts}/#{certname}.cert.pem",
                                                          "#{orchcerts}/#{certname}.cert.pem",
                                                        ])
    public_key = same_file("#{ssldir}/public_keys/#{certname}.pem", [
                                                          "#{puppetdbcerts}/#{certname}.public_key.pem",
                                                          "#{consolecerts}/#{certname}.public_key.pem",
                                                          "#{orchcerts}/#{certname}.public_key.pem",
                                                        ])
    private_key = same_file("#{ssldir}/private_keys/#{certname}.pem", [
                                                          "#{puppetdbcerts}/#{certname}.private_key.pem",
                                                          "#{pgsqlcerts}/_local.private_key.pem",
                                                          "#{consolecerts}/#{certname}.private_key.pem",
                                                          "#{orchcerts}/#{certname}.private_key.pem",
                                                        ])

    return (cert and public_key and private_key)
  end

  def same_file(filename, list)
    require 'digest'
    list  = Array(list) # coerce if needed
    left  = Digest::MD5.hexdigest(File.read(filename))

    list.each do |path|
      return false unless (left == Digest::MD5.hexdigest(File.read(path)))
    end

    return true
  end
end
