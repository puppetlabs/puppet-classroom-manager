class Classroom
  def validate
    require 'rake'
    require 'rspec/core/rake_task'

    puts "Validating configuration..."
    Dir.chdir(@config[:specdir]) do
      RSpec::Core::RakeTask.new(:spec) do |t|
        t.rspec_opts = "-I #{@config[:specdir]} --format progress"
        t.pattern    = 'localhost/*_spec.rb'
        t.verbose    = false
      end

      Rake::Task[:spec].invoke
    end

  end
end
