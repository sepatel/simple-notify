require 'getoptlong'

class CommandLine
  attr_reader :options, :parameters

  def initialize
    @parameters = []
    @options = {}
    @optionsConfig = {}
    @parametersConfig = []
    @examples = []
    @optionsConfig['help'] = {
      'short' => 'h',
      'long' => 'help',
      'type' => GetoptLong::NO_ARGUMENT,
      'description' => 'Shows the help/usage information'
    }
  end

  def [](index)
    @parameters[index]
  end

  def process
    optArray = []
    @optionsConfig.each { |key, value|
      optArray.push(['-' + value['short'], '--' + value['long'], value['type']])
    }
    opts = GetoptLong.new(*optArray)
    opts.each { |opt, arg|
      @options[opt[1,1]] = arg
    }

    if ARGV.length < @parametersConfig.length || @options.has_key?('h')
      puts to_s
      exit
    end
    @parameters = ARGV
  end

  def addParameter(name, description)
    @parametersConfig.push([name, description])
  end

  def addOption(short, long, type, description)
    @optionsConfig[long] = {
      'short' => short,
      'long' => long,
      'type' => type,
      'description' => description
    }
  end

  def addExample(example)
    @examples.push(example)
  end

  def to_s
    params = ''
    @parametersConfig.each { |key, value|
      params += sprintf("%s ", key)
    }

    usage = sprintf("\033[1mUsage:\033[0m\n  %s [OPTIONS] %s\n", $0, params)
    params = ''
    if @parametersConfig.length > 0
      params = "\n\033[1mParameters:\033[0m\n"
      @parametersConfig.each { |key, value|
        params += sprintf("  %s : %s\n", key.ljust(12), value)
      }
    end

    options = ''
    if @optionsConfig.length > 0
      options = "\n\033[1mOptions:\033[0m\n"
      @optionsConfig.sort.each { |key, value|
        padding = 20
        arg = ""
        if (@optionsConfig[key]['type'] == GetoptLong::OPTIONAL_ARGUMENT)
          arg = " \033[36m[arg]\033[0m"
          padding = 29
        end
        if (@optionsConfig[key]['type'] == GetoptLong::REQUIRED_ARGUMENT)
          arg = " \033[36m<arg>\033[0m"
          padding = 29
        end
        options += sprintf("  -%s, --%s : %s\n", value['short'], (value['long'] + arg).ljust(padding), value['description'])
      }
    end

    example = ''
    if @examples.length > 0
      example += "\n\033[1mExample:\033[0m\n"
      @examples.each { |value|
        example += "  #{$0} " + value + "\n"
      }
    end
    return usage + params + options + example;
  end  
end

