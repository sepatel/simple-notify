require 'rubygems'
require 'fileutils'
require 'json'

$DB_DIRECTORY = "datastore"

class Datastore
  class DbArray < Array
    def query(code)
      results = DbArray.new
      each {|row|
        result = code.call(row)
        if !result.nil?
          if block_given?
            yield result
          else
            results << result
          end
        end
      }
  
      return results;
    end

    def query_single(code)
      each {|row|
        result = code.call(row)
        return result unless result.nil?
      }
      return nil
    end
  end

  def initialize(dbname, tablenames=[])
    Dir.mkdir "#{$DB_DIRECTORY}" unless File.directory? $DB_DIRECTORY
    @dbdir = "#{$DB_DIRECTORY}/#{dbname}"
    @table = {}
    Dir.mkdir @dbdir unless File.directory? @dbdir
    Dir.entries("#{@dbdir}").each {|table|
      if table.match(/(.*)\.json$/)
        JSON.parse(IO.read("#{@dbdir}/#{table}")).each {|row|
          self[$1] = Class.class_eval(row['_type']).new(row)
        }
      end
    }
  end

  def [](name)
    @table[name] = DbArray.new if @table[name].nil?
    return @table[name]
  end

  def []=(name, value)
    @table[name] = DbArray.new if @table[name].nil?
    @table[name] << value
  end

  def commit(names=[])
    @table.each {|key, value|
      if names.size == 0 or names.include?(key)
        File.open("#{@dbdir}/#{key}.json", "w") {|file| file.write(value.to_json) }
      end
    }
  end
end

class DataObject
  def initialize(source=nil)
    return if source.nil?
    internal_hash = JSON.parse(source) if source.instance_of? String
    internal_hash = source if source.instance_of? Hash
    raise "Invalid Data Type: #{source.class}" if internal_hash.nil?
    internal_hash.each {|key, value|
      if @@data.include?(:"#{key}")
        if value.instance_of? Array
          newvalue = []
          value.each {|element|
            if element.instance_of? Hash and !element['_type'].nil?
              newvalue << Class.class_eval(element['_type']).new(element)
            else
              newvalue << element
            end
          }
          value = newvalue
        elsif value.instance_of? Hash
          newvalue = {}
          value.each {|k, element|
            if element.instance_of? Hash and !element['_type'].nil?
              newvalue[k] = Class.class_eval(element['_type']).new(element)
            else
              newvalue[k] = element
            end
          }
          value = newvalue
        end
        self.instance_variable_set("@#{key}", value) if self.respond_to?("#{key}=")
      end
    }
  end

  def to_hash
    hash = {:_type => self.class.name}
    @@data.each {|var|
      if self.respond_to?(var)
        value = self.instance_variable_get("@#{var}")
        if value.instance_of? DataObject
          hash[var] = value.to_hash
        else
          hash[var] = value unless value.nil?
        end
      end
    }
    return hash
  end

  def to_json(state=nil)
    return to_hash.to_json
  end

  private
  @@data = []
  def self.boolean(*a)
    @@data = @@data + a
    a.each {|m|
      define_method(m) { instance_variable_get("@#{m}") }
      define_method("#{m}=") {|val|
        raise ArgumentError.new("#{val} is not a boolean value") unless val.nil? or val.is_a?(TrueClass) or val.is_a?(FalseClass)
        instance_variable_set("@#{m}", val)
      }
    }
  end

  def self.date(*a)
    @@data = @@data + a
    a.each {|m|
      define_method(m) {
        secs = instance_variable_get("@#{m}")
        return Time.at(secs)
      }
      define_method("#{m}=") {|val|
        raise ArgumentError.new("#{val} is not a date value") unless val.nil? or val.is_a?(Time) or val.is_a?(Fixnum) or val.is_a?(Integer)
        if val.is_a?(Time)
          val = val.to_i
        end
        instance_variable_set("@#{m}", val)
      }
    }
  end

  def self.list(*a)
    @@data = @@data + a
    a.each {|m|
      define_method(m) {
        value = instance_variable_get("@#{m}")
        if value.nil?
          value = []
          instance_variable_set("@#{m}", value)
        end
        return value
      }
      define_method("#{m}=") {|val|
        raise ArgumentError.new("#{val} is not a list value") unless val.nil? or val.is_a?(Array)
        instance_variable_set("@#{m}", val)
      }
    }
  end

  def self.hash(*a)
    @@data = @@data + a
    a.each {|m|
      define_method(m) {
        value = instance_variable_get("@#{m}")
        if value.nil?
          value = {}
          instance_variable_set("@#{m}", value)
        end
        return value
      }
      define_method("#{m}=") {|val|
        raise ArgumentError.new("#{val} is not a hash value") unless val.nil? or val.is_a?(Hash)
        instance_variable_set("@#{m}", val)
      }
    }
  end

  def self.number(*a)
    @@data = @@data + a
    a.each {|m|
      define_method(m) { instance_variable_get("@#{m}") }
      define_method("#{m}=") {|val|
        raise ArgumentError.new("#{val} is not a number value") unless val.nil? or val.is_a?(Fixnum) or val.is_a?(Integer) or val.is_a?(Float)
        instance_variable_set("@#{m}", val)
      }
    }
  end

  def self.string(*a)
    @@data = @@data + a
    a.each {|m|
      define_method(m) { instance_variable_get("@#{m}") }
      define_method("#{m}=") {|val|
        instance_variable_set("@#{m}", val)
      }
    }
  end
end


## Hacky Testing
#class Test < DataObject
#  attr_accessor :id
#  boolean :male
#  date :birth
#  number :apple, :bear
#  string :name, :color
#  list :lottery
#  hash :config
#end
#t = Test.new("{\"apple\":4.3, \"birth\":8338921, \"_type\":\"Test\", \"color\":\"green\", \"bear\":true, \"lottery\":[\"world\"],\"male\":true,\"config\":{\"work\":\"AAA\"}}")
#t.id = 'hello'
#p [t.birth, t.to_hash]
#t.birth = 8348921
#t.apple = 4.5
#t.color = 'purple'
#t.male = true
#t.lottery << 'hello'
#p [t.birth, t.to_hash]
#t.birth = Time.now
#t.config['work'] = true
#p [t.birth, t.to_hash]
#
#class Trouble < DataObject
#  attr_accessor :silly
#end
#
#t = Test.new(:id => 'hocus pocus', :color => 'purple', :ignored => true, :birth => Date.new,
#      :list => [Trouble.new(:silly => 'grand papa smurf'), "String", 42],
#      :hash => {:a => "String", :b => 42, :c => Trouble.new(:silly => 'mars')})
#t.list << Trouble.new(:silly => 'billy')
#puts t.to_json
#
#def testmethod(row)
#  return row unless row.id.length > 6
#end
#
#db = Datastore.new('test')
#db['Test'] = t
#p db
#db['Test'].query(method(:testmethod)) { |record|
#  print "The recorded id is #{record.id}\n"
#}
#db.commit;
#
#results = db['Test'].query(lambda {|row| return row if row.id.length > 6})
#p results
#results.query(lambda {|row| return row unless row.hash.nil?}) {|result|
#  puts "Found #{result.list[0].silly} with hash #{result.hash["c"]}"
#}
