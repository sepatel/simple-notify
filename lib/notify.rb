require 'yaml'
require 'fileutils'
include FileUtils

module Notify

  def get_repo(repo_name)
    settings = YAML.load(IO.read("config/repo.yml"))
    return settings['repositories'][repo_name]
  end

  def checkout(repo)
    if File.exists?(repo['checkout-to'])
      cd repo['checkout-to']
      system("git pull")
    else
      cd File.dirname(repo['checkout-to'])
      baseName = File.basename(repo['checkout-to'])
    
      system("git clone #{repo['url']} #{baseName}")
    
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
    passed = []
    failed = []
    commands.each do |cmd|
      puts "Trying: #{cmd}"
      success = system("./#{cmd} >/tmp/out 2>&1")
      if success
        passed << cmd
      else
        failed << cmd
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
      system("echo \"Failed: #{failed[0]}\" | mail -s \"#{subject}\" #{recips}")
    end
  end
end
