class Classroom
  def reset(subject)
    if subject.size != 1
      puts <<-EOF
Usage: classroom reset <password | certificates | filesync>

This tool will reset or regenerate:
  * root's login password and update the /etc/issue screen
  * delete and redeploy all FileSync caches
  * *all* ssl certificates in the PE stack. (warning: destructive!)

EOF
      exit 1
    end

    case subject.first
    when :password
      reset_password
    when :certificates
      reset_certificates
    when :filesync
      reset_filesync
    else
      raise "Unknown action."
    end
  end

  def reset_password
    print "Enter new root password: "
    password = gets.chomp

    %x(echo "root:#{password}"|chpasswd)

    File.open('/var/local/password','w') do |f|
      f.puts password
    end

    %x(/etc/rc.local 2>/dev/null)
  end

  def reset_certificates
    require "fileutils"

    # Automate the process of regenerating certificates on a monolithic master
    # https://docs.puppet.com/pe/latest/trouble_regenerate_certs_monolithic.html
    #
    timestamp     = Time.now.to_i
    certname      = `puppet master --configprint certname`.strip
    ssldir        = '/etc/puppetlabs/puppet/ssl'
    puppetdbcerts = '/etc/puppetlabs/puppetdb/ssl'
    consolecerts  = '/opt/puppetlabs/server/data/console-services/certs'
    pgsqlcerts    = '/opt/puppetlabs/server/data/postgresql/9.4/data/certs'
    orchcerts     = '/etc/puppetlabs/orchestration-services/ssl'

    ["puppet", "puppetdb", "console-services", "postgresql", "orchestration"].each do |path|
      FileUtils.mkdir_p("/root/certificates.bak/#{path}")
    end
    FileUtils.cp_r("#{ssldir}",        "/root/certificates.bak/puppet/#{timestamp}")
    FileUtils.cp_r("#{puppetdbcerts}", "/root/certificates.bak/puppetdb/#{timestamp}")
    FileUtils.cp_r("#{consolecerts}",  "/root/certificates.bak/console-services/#{timestamp}")
    FileUtils.cp_r("#{pgsqlcerts}",    "/root/certificates.bak/postgresql/#{timestamp}")
    FileUtils.cp_r("#{orchcerts}",     "/root/certificates.bak/orchestration/#{timestamp}")

    puts "Certificates backed up to ~/certificates.bak"

    puts
    puts
    puts "#####################################################################"
    puts
    puts "      If you regenerate the Puppet CA to start fresh, then"
    puts "ALL client certificates will be invalidated and must be regenerated!"
    puts
    puts "        -- This should only be done as a last resort --"
    puts
    puts "#####################################################################"
    puts
    if confirm?('Would you like to regenerate the CA?', false)
      FileUtils.rm_rf("#{ssldir}/*")
      system("puppet cert list -a")
    end

    FileUtils.rm_f("/opt/puppetlabs/puppet/cache/client_data/catalog/#{certname}.json")
    system("puppet cert clean #{certname}")
    system("puppet infrastructure configure --no-recover")
    system("puppet agent -t")

    puts "All done. If you regenerated the CA, then regenerate all client certificates now."
  end

  def reset_filesync
    puts
    puts
    puts "################################################################################"
    puts
    puts "This script will completely delete and redeploy all environments without backup!"
    puts "            The operation may take up to five minutes to complete."
    puts
    puts "################################################################################"
    puts
    bailout?

    system("systemctl stop pe-puppetserver")

    # filesync cache
    FileUtils.rm_rf("/opt/puppetlabs/server/data/puppetserver/filesync")

    # r10k cache
    FileUtils.rm_rf("/opt/puppetlabs/server/data/code-manager/git")

    # code manager worker thread caches
    FileUtils.rm_rf("/opt/puppetlabs/server/data/code-manager/worker-caches")
    FileUtils.rm_rf("/opt/puppetlabs/server/data/code-manager/cache")

    # possibly stale environment codebases
    FileUtils.rm_rf("/etc/puppetlabs/code/*")
    FileUtils.rm_rf("/etc/puppetlabs/code-staging/environments")

    system("systemctl start pe-puppetserver")
    system("puppet code deploy --all --wait")
  end
end
