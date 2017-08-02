class Classroom
  def page
    require 'json'
    require 'rest-client'

    begin
      config = JSON.parse(File.read('/opt/pltraining/etc/classroom.json'))
      pd_key = File.read('/opt/pltraining/etc/pagerduty.key')
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
      puts "Sending page. Make sure you've posted about the issue in HipChat."
      config = load_metadata
      page_message = "Instructor: #{config['name']}\n" +
                     "Email: #{config['email']}\n" +
                     "Course: #{config['course']}\n" +
                     "ID: #{config['event_id']}"
      page_data = {
        "service_key" => pd_key,
        "event_type"  => "trigger",
        "description" => page_message
      }
      response = RestClient.post(
        "https://events.pagerduty.com/generic/2010-04-15/create_event.json",
        page_data.to_json,
        :content_type => :json,
        :accept => :json
      )
      puts response
    end
  end
end
