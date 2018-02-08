class Classroom
  require 'classroom/page'
  require 'classroom/performance'
  require 'classroom/reset'
  require 'classroom/restart'
  require 'classroom/sanitize'
  require 'classroom/submit'
  require 'classroom/troubleshoot'
  require 'classroom/validate'
  require 'classroom/version'

  def initialize(config)
    @config = config
  end

  def update
    puts "Updating system and courseware..."
    system("#{@config[:bindir]}/puppet agent -t --confdir #{@config[:confdir]}")
  end

  def confirm?(message = 'Continue?', default = true)
    if default
      print "#{message} [Y/n]: "
      return [ 'y', 'yes', '' ].include? STDIN.gets.strip.downcase
    else
      print "#{message} [y/N]: "
      return [ 'y', 'yes' ].include? STDIN.gets.strip.downcase
    end
  end

  def bailout?(message = 'Continue?')
    raise "User cancelled" unless confirm?(message)
  end

  def check_success(status=nil)
    status = status.nil? ? ($? == 0) : status

    if status
      printf("\[\033[32m  OK  \033[0m]\n")
    else
      printf("[\033[31m FAIL \033[0m]\n")
    end
  end

  def showoff_config
    presentation = showoff_working_directory()
    data         = JSON.parse(File.read("#{presentation}/stats/metadata.json")) rescue {}

    data['event_id'] ||= Time.now.to_i
    data['course']   ||= File.basename(presentation.strip)
    data
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
    data['WorkingDirectory'].strip
  end

  def help
    require 'classroom/help'
    puts Classroom::HELP
  end

  def debug
    require 'pry'
    binding.pry
  end

end
