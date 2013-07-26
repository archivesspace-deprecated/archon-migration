
class Job


  def initialize(params)
    params.each do |k, v|
      self.instance_variable_set(k, v)
    end
  end


  def results
    "Success"
  end

end
