class Classroom
  def restart(subject)
    if subject.empty?
      puts <<-EOF
This tool simply helps restart the PE services in the right order.
It will send a HUP signal to Puppetserver by default which is much
faster than a full restart.

You can also restart Docker containers in classes that use them.

If you do need the full restart, please pass the -f option.

Service names:
    * puppetserver
    * console
    * puppetdb
    * orchestration
    * mcollective
    * containers
    * all (restart all PE services in the proper order)

Examples:
    * classroom restart puppetdb puppetserver
    * classroom restart puppetserver console -f
    * classroom restart all -f

EOF
      exit 1
    end

    # normalize to lowercase strings so we can pattern match
    subject.map! { |x| x.to_s.downcase }

    if subject.include? 'all'
      puts "Restarting all PE stack services. This may take a few minutes..."
      subject.concat ['puppetdb', 'puppetserver', 'orchestrator', 'console', 'mcollective', 'puppet']
      subject.uniq!
    else
      puts "Restarting selected PE components."
    end

    if subject.grep(/puppetdb|pdb/).any?
      restart_service('pe-postgresql.service')
      restart_service('pe-puppetdb.service')
    end

    if subject.grep(/puppetserver|server/).any?
      if @config[:force]
        restart_service('pe-puppetserver.service')
      else
        reload_service('pe-puppetserver.service', 'puppet-server')
      end
    end

    if subject.grep(/orch|pxp/).any?
      restart_service('pe-orchestration-services.service')
      restart_service('pxp-agent.service')
    end

    if subject.grep(/console/).any?
      restart_service('pe-console-services.service')
      restart_service('pe-nginx.service')
    end

    if subject.grep(/mco/).any?
      restart_service('pe-activemq.service')
      restart_service('mcollective.service')
    end

    if subject.include? 'puppet'
      restart_service('puppet.service')
    end

    if subject.include? 'containers'
      `systemctl list-units`.each_line do |line|
          restart_service($1) if line =~ /^(docker-\S+)/
      end
    end

  end

  def restart_service(service)
    puts "- Restarting #{service}..."
    system("systemctl restart #{service}")
  end

  def reload_service(service, pattern)
    puts "> Reloading #{service}..."
    system("kill -HUP `pgrep -f #{pattern}`")
  end
end
