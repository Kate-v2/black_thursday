require 'pry'



module SAMath

  # --- General Methods ---

  # TO DO - Test the method part
  def sum(values, method = nil)
    values.inject(0) { |total, val|
      val = val.send(method) if method
      total += val
     }
   end

  def average(values, ct = values.count)
    sum     = sum(values)
    ct      = ct.to_f
    average = (sum / ct)
  end   # returns an unrounded float

  def percentage(fraction, all)
    (fraction / all.to_f ) * 100
  end

  def standard_deviation(values, mean) # Explicit steps
    floats      = values.map     { |val| val.to_f   }
    difference  = floats.map     { |val| val - mean }
    values      = difference.map { |val| val ** 2   }
    sample_ct   = (values.count - 1)
    div         = average(values, sample_ct)
    sqrt        = Math.sqrt(div)
    return sqrt.round(2)
  end   # returns float rounded to 2 places

  def standard_dev_measure(values, above_or_below, std = nil)
    mean = average(values)
    std == nil ? std = standard_deviation(values, mean) : std
    outside_this = mean + (std * above_or_below)
  end # returns a float

  def find_exceptional(collection, values, stds, method)
    case collection
    when Hash;  exceptional_from_hash(collection, values, stds, method)
    when Array; exceptional_from_array(collection, values, stds, method)
    end
  end

  def exceptional_from_hash(collection, values, stds, method)
    stds > 0 ? operator = :> : operator = :<
    std_limit = standard_dev_measure(values, stds)
    list = collection.find_all {|key, value|
      value.send(method).send(operator, std_limit)
    }.to_h
    return list
  end

  def exceptional_from_array(collection, values, stds, method)
    stds > 0 ? operator = :> : operator = :<
    std_limit = standard_dev_measure(values, stds)
    list = collection.find_all {|object|
      object.send(method).send(operator, std_limit)
    }
    return list
  end

end
