class Classroom
  def performance(subject)
    if subject.empty?
      puts "This will take performance related snapshots, which will be uploaded for"
      puts "engineering analysis. You may also record performance notes into the log."
      puts
      puts "Usage: classroom performance [ log <message>  | snapshot ]"
      puts
      puts "  * log: Record a message into classroom log and take a snapshot."
      puts "  * snapshot: Save snapshot of classroom statistics."
      puts
      exit 1
    end

    case subject.shift
    when 'log'
      message = subject.empty? ? "Misc performance issue noted." : subject.join(' ')
      $logger.warn message
      record_snapshot

    when 'snapshot'
      $logger.debug "Scheduled performance snapshot"
      record_snapshot

    else
      raise "No such action"
    end

    def record_snapshot
      $logger.debug "-------------------------------- top -bn1 ----------------------------------\n#{`top -bn1`}"
      $logger.debug "-------------------------------- vmstat ------------------------------------\n#{`vmstat`}"
      $logger.debug "-------------------------------- netstat -a --------------------------------\n#{`netstat -a`}"
      $logger.debug "-------------------------------- iostat ------------------------------------\n#{`iostat`}"
      $logger.debug "-------------------------------- mpstat -P ALL -----------------------------\n#{`mpstat -P ALL`}"

      FileUtils.mkdir_p '/var/log/puppetlabs/classroom-traffic'
      `tcpdump -G 15 -W 1 -w /var/log/puppetlabs/classroom-traffic/#{Time.now.to_i}.pcap -i any > /dev/null 2>&1 &`
    end

  end
end
