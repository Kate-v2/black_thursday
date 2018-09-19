class FinderClass


  # === Finding Management =================================

  def self.find_by(repo, method, data)
    repo.find {|object| object.send(method) == data }
  end # returns an object / the first object

  def self.find_all_by(repo, method, data)
    repo.find_all {|object| object.send(method) == data }
  end # returns an array of objects

  def self.find_max(repo, method)
    repo.max_by { |object| object.send(method) }
  end # returns an object (not the max value itself)

  def self.find_by_range(repo, method, range)
    list = repo.find_all { |object| range.include?(object.send(method))}
  end

  def self.find_by_insensitive(repo, method, data)
    data = data.downcase
    obj = repo.find { |object|
      value = object.send(method).downcase
      value == data
    }; return obj
  end

  def self.find_all_by_insensitive(repo, method, data)
    data = data.downcase
    list = repo.find_all{ |object|
      value = object.send(method).downcase
      value == data
    }; return list
  end

  def self.find_by_fragment(repo, method, frag)
    frag = frag.downcase
    list = repo.find_all{ |object|
      value = object.send(method).downcase
      value.include?(frag)
    }; return list
  end


  # === Grouping Management =================================

  def self.group_by(collection, method)
    collection.group_by { |obj| obj.send(method) }
  end

  def self.make_array(array, method)
    array.inject([]) { |arr, obj| arr << obj.send(method) }
  end


  # === Matching Management =================================

  def self.match_by_data(repo, collection, method)
    collection.map { |data|
      repo.find_all { |obj| obj.send(method) == data }
    }.flatten
  end


  # === Date Management =================================

  def self.day_of_week(integer)
    case integer
    when 0; "Sunday"
    when 1; "Monday"
    when 2; "Tuesday"
    when 3; "Wednesday"
    when 4; "Thursday"
    when 5; "Friday"
    when 6; "Saturday"
    end
  end

  def self.find_by_all_by_date(repo, method, date)
    date = date_to_string(date)
    date.class == Date ? date = date.to_s : date = date.to_s.split[0]
    repo.find_all { |obj|
      obj_date = obj.send(method)
      obj_date = date_to_string(obj_date)
      obj_date == date
    }
  end

  def self.date_to_string(date)
    date.class == Date ? date = date.to_s : date = date.to_s.split[0]
  end


end
