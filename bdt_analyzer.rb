class BDT
  # set normalization numbers based on previously produced entire BDT tracer (simplified because of huge file) 

  def set_normalized_numbers
    classes_h = JSON.parse(File.read('classes.json'))
    steps_h = JSON.parse(File.read('steps.json'))
    scenarios_h = JSON.parse(File.read('scenarios.json'))
    model_count_h, method_count_h = sort_analysis_result_with_methods(classes_h)
    PER_SCEN_MODEL = normalize_to_1(model_count_h.dup, scenarios_h.length)
    PER_SCEN_METHOD = normalize_to_1(method_count_h.dup, scenarios_h.length)
  end

  # analyze a bdt logfile and print normalized reports
  def analyze(logfile='comments_delete')
    classes, user_stories, scenarios, steps = analyzer(logfile)
    model_count, method_count = sort_analysis_result_with_methods(classes)
    norm_method_count = normalized_analysis(method_count, kind='method')
    norm_model_count = normalized_analysis(model_count, kind='model')
    print_sorted_hash(norm_model_count)
    print_sorted_hash(norm_method_count)
    return [norm_model_count, norm_method_count
  end

  # apply normalization division
  def normalized_analysis(counts, kind='model')
    norm_counts = counts.dup
    norm_counts.delete('mtds')
    norm_counts.each do |k,v|
      division = eval("PER_SCEN_#{kind.upcase}")[k] || 1
      if division == nil or division == 0 then division = 1 end
      norm_counts[k] = v/division
    end
    norm_counts = convert_to_percentages(norm_counts)
  end

  def normalize(hsh, division)
    hsh.each { |k,v| hsh[k] = (v.to_f/division)}
    hsh.each { |k,v| if v.round == 0 then hsh[k] = v.ceil end }
  end

  def convert_to_percentages(hsh)
    division = hsh.values.sum()
    hsh.each { |k,v| hsh[k] = v.to_f/division*100 }
  end


  # sort and pretty print a hash
  def print_sorted_hash(hsh)
    pp Hash[hsh.sort_by{|k, v| v}.reverse]
  end
  # Big ugly analyzer that actually processes the huge logfiles into manageable data structures
  def analyzer(logfile='comments_delete')
    @classes = { "models" => { 'mtds' => [] }, "controllers" => { 'mtds' => [] }, "other" => { 'mtds' => [] } }
    @scenarios = Set.new
    @steps = Set.new
    @user_stories = Set.new
    File.open(logfile, 'r') do |tp_log|
      tp_log.each_line do |logline|
        log_entry = logline.split(',').each {|l| l.strip! }
        kinds = ['models','controllers'] ; kind = 'other'
        kinds.each { |k| kind = log_entry[0].include?(k) ? k : kind} 
        klasses = log_entry[1].split(':').reject(&:empty?)
        eval_klass = "@classes['#{kind}']"
        klasses.each.with_index(1) do |klass, idx|
          if idx == klasses.length
            eval(eval_klass+"['mtds']") << klass
          else
            eval(eval_klass+"['#{klass}'] ||= {'mtds' => []}")
          end
          eval_klass += "['#{klass}']"
        end
        @user_stories.add(log_entry[2])
        @scenarios.add(log_entry[3])
        @steps.add(log_entry[4])
      end
    end
    return [@classes, @user_stories, @scenarios, @steps]
  end

  def count_all_keys(hsh)
    hsh.map do |k,v|
      Hash === v ? count_all_keys(v) : v.length
    end.flatten
  end
  
  # takes initial processed data and counts number of class and method calls for reporting
  def sort_analysis_result_with_methods(classes)
    models = classes['models']
    method_count = Hash.new(0)
    model_count = Hash[ models.keys.collect { |m| [ m, 0 ] }]
    models.keys.each do |key|
      model_count[key] += count_all_keys(models[key]).sum()
      # count method calls
      unless key == 'mtds'
        models[key]['mtds'].each {|m| method_count["#{key}:#{m}"] += 1}
        # model_count[key][1] = Hash[method_count.sort_by{|k, v| v}.reverse]
      end
    end
    return model_count, method_count
  end
end