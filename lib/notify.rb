require 'yaml'
require 'fileutils'
require 'erb'
require 'alert'
include FileUtils

module Notify

  def get_repo(repo_name)
    settings = YAML.load(IO.read("config/repo.yml"))
    return settings['repositories'][repo_name]
  end

  def checkout(repo)
    cmd = repo['git-cmd'] || "git"

    if File.exists?(repo['checkout-to'])
      cd repo['checkout-to']
      system("#{cmd} pull")
    else
      cd File.dirname(repo['checkout-to'])
      baseName = File.basename(repo['checkout-to'])
    
      system("#{cmd} clone #{repo['url']} #{baseName}")
    
      cd repo['checkout-to']
    end
  end

  def find_commands(repo)
    cd repo['commands']
    puts "Pwd: #{pwd()}"
    commands = []
    Dir.glob("*") do |f|
      if File.executable?(f)
        puts "Found: #{f}"
        commands << f
      end
    end
    return commands
  end

  def run_commands(repo)
    commands = find_commands(repo)
    results = []
    commands.each do |cmd|
      puts "Trying: #{cmd}"
      output = %x[./#{cmd} 2>&1]
      success = $? == 0
      results << Alert.new(cmd, success, output)
      clean_up(repo)
    end
    return results
  end
 
  def generate_report(repo, base, results)
    failed = results.reject {|x| x.passed?}
    passed = results.select {|x| x.passed?}

    puts "----------------"
    puts "Report"
    puts "Passed: #{passed.length}"
    puts "Failed: #{failed.length}"

    report_dir = repo['report-to'] 
    if report_dir
    
      mkdir report_dir if !File.exists?(report_dir)
       
      output_template = IO.read("#{base}/templates/output.rhtml")
      index_template = IO.read("#{base}/templates/index.rhtml")
  
      results.each do |alert|
        filename = "#{report_dir}/#{alert.name}.txt"
        File.open(filename, "w+") do |f|
          f.write(ERB.new(output_template).result(binding))
        end
      end

      index_filename = "#{report_dir}/index.html"
      File.open(index_filename, "w+") do |f|
        f.write(ERB.new(index_template).result(binding))
      end
      
    end
  end

  def handle_alert(repo, base, results)
    failed = results.reject {|x| x.passed?}
    if !failed.empty?
      puts "Send alert to #{repo['alert']}"
      subject = "#{failed.length} #{repo['subject']}"
      template_filename = repo['template'] || "failure-email.erb"
      recips = repo['alert'].gsub(',', ' ')

      report = "/tmp/report-#{Process.pid}.txt"

      template = IO.read("#{base}/templates/#{template_filename}")

      File.open(report, "w+") do |f|
        f.write(ERB.new(template).result(binding))
      end

      system("cat #{report} | mail -s \"#{subject}\" #{recips}")
      rm report
    end
  end

  def clean_up(repo)
    cmd = repo['git-cmd'] || "git"

    if File.exists?(repo['checkout-to'])
      old_dir = pwd
      cd repo['checkout-to']
      system("#{cmd} clean -f")
      cd old_dir
    end
  end
end
