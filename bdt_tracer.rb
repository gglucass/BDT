#add the following to env.rb in a Ruby on Rails project to enable BDT

$tp_logger = ""
rb_files = Dir["**/*.rb"]
TRACER = TracePoint.new(:call) do |tp|
  tp_rel_path = tp.path.gsub(Rails.root.to_s + '/', "")
  # filetype = ['models', 'controllers'].any? { |ft| tp_rel_path.include?(ft) }
  if rb_files.include?(tp_rel_path) #&& filetype
    $tp_logger << "#{tp_rel_path}, #{tp.defined_class.to_s.gsub("#<Class:", "").gsub(/\(.*\)>/, "")}:#{tp.method_id}, #{$user_story.dump}, #{$test_case}, #{$test_step}\n"
  end
end

Before do |scenario|
  $user_story = scenario.source[0].description
end

AfterConfiguration do |config|
  config.on_event :before_test_case do |event|
    $test_case = event.test_case.location.to_s
    puts $test_case
  end

  config.on_event :before_test_step do |event|
    if event.test_step.name != 'Before hook' and event.test_step.name != 'After hook'
      $test_step = event.test_step.location.to_s
      TRACER.enable
    end
  end

  config.on_event :after_test_step do |event|
    if event.test_step.name != 'Before hook' and event.test_step.name != 'After hook'
      event.test_step.location.to_s
      TRACER.disable
    end
  end
end

at_exit do
  File.open('log/bdt_logs/bdt', "w") { |f| f.write($tp_logger) 
end