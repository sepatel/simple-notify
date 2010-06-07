require 'yaml'
require 'fileutils'
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

  def run_commands(commands)
    passed = {}
    failed = {}
    commands.each do |cmd|
      puts "Trying: #{cmd}"
      output = %x[./#{cmd} 2>&1]
      success = $? == 0
      if success
        passed[cmd] = output
      else
        failed[cmd] = output
      end
    end
    return passed, failed
  end
 
  def display_report(passed, failed)
    puts "----------------"
    puts "Report"
    puts "Passed: #{passed.length}"
    puts "Failed: #{failed.length}"
  end

  def handle_alert(repo, failed)
    if !failed.empty?
      puts "Send alert to #{repo['alert']}"
      subject = "#{failed.length} #{repo['subject']}"
      recips = repo['alert'].gsub(',', ' ')

      report = "/tmp/report-#{Process.pid}.txt"

      File.open(report, "w+") do |f|
        failed.each do |k,v|
          f.write "#{k}\n"
          f.write v
          f.write "-----------------------\n"
        end
      end 

      #system("echo \"Failed: #{failed[0]}\" | mail -s \"#{subject}\" #{recips}")
      system("cat #{report} | mail -s \"#{subject}\" #{recips}")
      rm report
    end
  end
end
