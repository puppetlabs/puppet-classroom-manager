class Classroom
  def submit
    require 'fileutils'
    require 'aws-sdk'

    if puppetlabs_instructor?
      puts "Please go to your learn dashboard and ensure that attendance is accurate"
      puts "and then close this class delivery to mark it as complete."
      puts " -- #{@config[:learndot]}"
      puts
    end

    presentation = showoff_working_directory()

    data = JSON.parse(File.read("#{presentation}/stats/metadata.json")) rescue {}
    event_id = data['event_id'] || Time.now.to_i
    course   = data['course']   || 'none'
    email    = data['email']    || 'none'

    begin
      # depends on root's credentials as managed by bootstrap
      s3 = Aws::S3::Resource.new(region:'us-west-2')

      # record the module versions in use
      system("puppet module list > /var/log/puppetlabs/classroom-modules")

      filename = "classroom-perflogs-#{course}-#{email}-#{event_id}.tar.gz"
      system("tar -cf /var/cache/#{filename} /var/log/puppetlabs/")
      obj = s3.bucket(PERF_BUCKET).object(filename)
      obj.upload_file("/var/cache/#{filename}")
      FileUtils.rm(filename)

      filename = "classroom-stats-#{course}-#{email}-#{event_id}.tar.gz"
      system("tar -cf /var/cache/#{filename} #{presentation}/stats/")
      obj = s3.bucket(STATS_BUCKET).object(filename)
      obj.upload_file("/var/cache/#{filename}")
      FileUtils.rm(filename)

    rescue LoadError, StandardError => e
      LOGGER.warn "S3 upload failed. No network?"
      LOGGER.warn e.message
      LOGGER.debug e.backtrace
    end

    # clean up for next delivery
    system("puppet resource service showoff-courseware ensure=stopped")
    FileUtils.rm_rf("#{presentation}/stats")
    FileUtils.rm_f("#{presentation}/courseware.yaml")
    FileUtils.rm_f("#{presentation}/_files/share/nearby_events.html")
    system("puppet resource service showoff-courseware ensure=running")

  end

  def puppetlabs_instructor?
    # TODO: how do?
    false
  end

  def showoff_working_directory
    # get the path of the currently configured showoff presentation
    data = {}
    path = '/usr/lib/systemd/system/showoff-courseware.service'
    File.read(path).each_line do |line|
      setting = line.split('=')
      next unless setting.size == 2

      data[setting.first] = setting.last
    end
    data['WorkingDirectory']
  end

end
