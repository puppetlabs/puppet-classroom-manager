class Classroom
  def page
    require 'json'
    require 'rest-client'

    begin
      config = showoff_config
      pd_key = File.read('/opt/pltraining/etc/pagerduty.key').strip
      raise 'Missing PagerDuty key' if pd_key.empty?
    rescue => e
      puts "Cannot load configuration"
      puts e.message
      exit 1
    end

    puts "---------  You're about to page and possibly wake somone up.  ---------"
    puts "Please check the Troubleshooting Guide for solutions to common problems."
    puts
    puts "https://github.com/puppetlabs/courseware/blob/master/TroubleshootingGuide.md"
    puts
    if confirm?("Have you done everything in the troubleshooting guide?") then
      print 'Describe the problem in a short sentence: '
      description  = STDIN.gets.strip

      print 'Enter the email or phone number where you can be reached: '
      contact      = STDIN.gets.strip

      page_message = "#{description}\n" +
                     "Contact: #{contact}\n" +
                     "Course: #{config['course']} #{config['version']}\n" +
                     "ID: #{config['event_id']}"
      page_data = {
        "service_key" => pd_key,
        "event_type"  => "trigger",
        "description" => page_message
      }

      puts "Sending page. Make sure you've posted about the issue in HipChat."
      response = JSON.parse(RestClient.post(
        "https://events.pagerduty.com/generic/2010-04-15/create_event.json",
        page_data.to_json,
        :content_type => :json,
        :accept => :json
      ))
      puts response unless response['status'] == 'success'
    end
  end
end
