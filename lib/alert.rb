class Alert
  attr_accessor :name, :failures, :success, :output

  def initialize(name, success, output)
    @name = name
    @success = success
    @output = output
  end

  def passed?
    @success
  end
  def <=>(other)
    @name <=> other.name 
  end
end
