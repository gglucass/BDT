require 'json'
require 'set'

class BDT
  PER_SCEN_MODEL_ADV = {}
  PER_SCEN_METHOD_ADV = {}
  def analyze(log_folder='log/bdsp_logs/all')
    classes, mtds, features = analyzer(log_folder)
    per_model, per_method = set_division_numbers(classes, mtds)
    stories = {}
    features.each do |title, feature|
      model_perc, method_perc = analyze_feature(feature['classes'])
      stories[title] = {"classes" => model_perc, "methods" => method_perc}
    end
    return stories
  end

  def analyze_feature(classes)
    model_count, method_count = sort_analysis_result(classes)
    model_count.map { |k,v| model_count[k] = v[0]}
    norm_method_count = normalized_analysis(method_count, kind='method')
    norm_model_count = normalized_analysis(model_count, kind='model')
    return [norm_model_count, norm_method_count]
  end

  def set_division_numbers(classes, mtds)
    model_count, method_count = sort_analysis_result(classes)
    model_count.map { |k,v| model_count[k] = v[1]}
    mtds_dup = mtds.dup
    mtds_dup['models'].map { |k,v| mtds_dup['models'][k] = v.length}
    # PER_SCEN_MODEL_ADV = model_count
    # PER_SCEN_METHOD_ADV = mtds_dup['models']
    $per_scen_model_adv = model_count
    $per_scen_method_adv = mtds_dup['models']
    return model_count, mtds_dup['models']
  end

  # apply normalization division
  def normalized_analysis(counts, kind='model')
    norm_counts = counts.dup
    norm_counts.delete('mtds')
    norm_counts.each do |k,v|
      division = eval("$per_scen_#{kind.downcase}_adv")[k] || 1
      if division == nil or division == 0 then division = 1 end
      norm_counts[k] = v.to_f/division
    end
    norm_counts = convert_to_percentages(norm_counts)
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
  def analyzer(logs_folder='log/bdsp_logs/all')
    @classes = { "models" => { 'mtds' => {} }, "controllers" => { 'mtds' => {} }, "other" => { 'mtds' => {} } }
    @methods = { "models" => {}, "controllers" => {}, "other" => {} }
    @features = {}
    logfiles = Dir[logs_folder+"/*"]
    logfiles.each do |logfile|
      logfile_name = logfile.split('/')[-1]
      puts "Starting on #{logfile_name}"
      @story_classes = { "models" => { 'mtds' => {} }, "controllers" => { 'mtds' => {} }, "other" => { 'mtds' => {} } }
      @story_methods = { "models" => {}, "controllers" => {}, "other" => {} }
      File.open(logfile, 'r') do |tp_log|
        tp_log.each_line do |logline|
          log_entry = logline.split(',').each {|l| l.strip! }
          kinds = ['models','controllers'] ; kind = 'other'
          kinds.each { |k| kind = log_entry[0].include?(k) ? k : kind} 
          klasses = log_entry[1].split(':').reject(&:empty?)
          if kind == 'models'
            eval_klass = "@classes['#{kind}']"
            eval_story_klass = "@story_classes['#{kind}']"
            klasses.each.with_index(1) do |klass, idx|
              if idx == klasses.length
                eval("#{eval_klass}['mtds']['#{klass}'] = #{eval_klass}['mtds'][#{'klass'}].try(:next) || 1")
                eval("#{eval_story_klass}['mtds']['#{klass}'] = #{eval_story_klass}['mtds']['#{klass}'].try(:next) || 1")
                @methods["#{kind}"]["#{klasses[idx-2]}:#{klass}"] ||= Set.new
                @story_methods["#{kind}"]["#{klasses[idx-2]}:#{klass}"] ||= Set.new
                @methods["#{kind}"]["#{klasses[idx-2]}:#{klass}"].add(log_entry[3])
                @story_methods["#{kind}"]["#{klasses[idx-2]}:#{klass}"].add(log_entry[3])
              elsif idx == 1
                  eval(eval_klass+"['#{klass}'] ||= {'mtds' => {}, 'bdt_scenarios' => Set.new}")
                  eval(eval_klass+"['#{klass}']['bdt_scenarios'].add(log_entry[3])")
                  eval(eval_story_klass+"['#{klass}'] ||= {'mtds' => {}, 'bdt_scenarios' => Set.new}")
                  eval(eval_story_klass+"['#{klass}']['bdt_scenarios'].add(log_entry[3])")
              else
                eval(eval_klass+"['#{klass}'] ||= {'mtds' => {} }")
                eval(eval_story_klass+"['#{klass}'] ||= {'mtds' => {} }")
              end
              eval_klass += "['#{klass}']"
              eval_story_klass += "['#{klass}']"
            end
          end
        end
      end
      @features[logfile_name] = {"classes" => @story_classes, "methods" => @story_methods}
    end
    return @classes, @methods, @features
    # return [@classes, @user_stories, @scenarios, @steps]
  end

  def count_all_keys(hsh)
    hsh.map do |k,v|
      if Hash === v and k != 'mtds'
        count_all_keys(v)
      elsif k == 'mtds'
        v.values.sum()
      else
        0
      end
    end.flatten
  end
  
  # takes initial processed data and counts number of class and method calls for reporting
  def sort_analysis_result(classes)
    models = classes['models']
    method_count = Hash.new(0)
    model_count = Hash[ models.keys.collect { |m| [ m, [0,0] ] }]
    models.keys.each do |key|
      model_count[key][0] += count_all_keys(models[key]).sum()
      
      # count method calls
      unless key == 'mtds'
        model_count[key][1] += models[key]['bdt_scenarios'].length 
        models[key]['mtds'].each {|k,v| method_count["#{key}:#{k}"] = v}
        # models[key]['GeneratedFeatureMethods'].each {|m| method_count["#{key}:#{m}"] += 1}
      end
    end
    return model_count, method_count
  end

  def export_markdown_report(stories)
    md_str =  "BDD feature    | User story     | Top 5 unique methods \n"
    md_str += "-------------- | -------------- | -------------------- \n"
    stories.each do |story, value|
      begin
        top_5_methods = (value['methods'].sort_by{|k, v| v}.reverse)[0..4]
        md_str += "#{story} | #{story} | #{top_5_methods[0][0]} (#{top_5_methods[0][1].round(2)}%)"
        top_5_methods[1..4].each do |mtd|
          md_str += " <br/> #{mtd[0]} (#{mtd[1].round(2)}%)"
        end
        md_str += "\n"
      rescue
        md_str += "#{story} | #{story} | !error!\n"
      end
    end
    File.open("log/bdt_output/stories_report.md", "w") { |f| f.write(md_str) }
  end

end