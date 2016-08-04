module JsonQuery
  module Data

    def self.walk(data:, path:)
      current = data
      path.each do |segment|
        results = segment.match(/^(.*)\[([0-9]+)\]$/)
        key, index = if results
          results.captures
        else
          [segment, nil]
        end
        if current.has_key?(key)
          current = current[key]
        else
          puts "Path #{path.join(".")} is not valid: the key `#{segment}` is not present."
          exit 1
        end
        if index
          index = index.to_i
          if is_list?(current) && current.count > index
            current = current[index]
          else
            puts "Path #{path.join(".")} is not valid: not a list of the index is out of bound."
            exit 1
          end
        end
      end
      current
    end

    def self.is_list?(value)
      value.is_a?(Array)
    end

    def self.is_set?(value)
      value.is_a?(Hash)
    end

    def self.build_paths(path: nil, data:, paths: [])
      if is_set?(data)
        data.map do |key, value|
          new_key = [path, key].compact.join(".")
          paths << new_key
          build_paths(path: new_key, data: value, paths: paths)
        end
      elsif is_list?(data)
        data.map.with_index do |value, index|
          new_key = [path, "[#{index}]"].compact.join
          paths << new_key
          build_paths(path: new_key, data: value, paths: paths)
        end
      else
        # it is a scalar, ignoring
      end
      paths
    end

  end
end
