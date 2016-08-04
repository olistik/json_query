require "set"
require "json_query/version"
require "json_query/composite_path"
require "json_query/composite_query"
require "json_query/query_match_results"
require "json_query/data"

module JsonQuery

  def self.perform(data:, query:, deep: false)
    paths = Data::build_paths(data: data).map do |path|
      CompositePath.new(base: path, segments: path.split("."))
    end
    expand_query(query: query).map do |query|
      match_query_against_paths(query: query, paths: paths, data: data)
    end.select(&:has_matching_paths?).map do |query_match_results|
      query_match_results.paths.map do |path|
        {
          value: Data::walk(path: path.segments, data: data),
          path: path.base
        }
      end
    end.flatten.map do |result|
      {
        path: result[:path],
        value: deep_value(value: result[:value], deep: deep)
      }
    end
  end

  private

  def self.deep_value(value:, deep:)
    if deep
      value
    else
      if Data::is_list?(value)
        :list
      elsif Data::is_set?(value)
        :set
      else
        value
      end
    end
  end

  # query = "de,wor.goo,face.details"
  # creates 4 paths:
  #   de.goo.details
  #   de.face.details
  #   wor.goo.details
  #   wor.face.details
  # (reduce + product: http://stackoverflow.com/a/29185756/528483)
  def self.expand_query(query:)
    if query.include?(",")
      if query.include?(".")
        query.split(".").map do |segment_string|
          segment_string.split(",")
        end.reduce do |memo, segment|
          memo.product(segment).map(&:flatten)
        end
      else
        query.split(",").map do |expansion|
          [expansion]
        end
      end.map do |segments|
        CompositeQuery.new(base: segments.join("."), segments: segments)
      end
    else
      [
        CompositeQuery.new(base: query, segments: query.split("."))
      ]
    end
  end

  def self.match_query_against_paths(query:, paths:, data:)
    matching_paths = paths.select do |path|
      match_query_against_path(
      query: query,
      path: path,
      data_reference: data
      )
    end.reverse.reduce([]) do |memo, item|
      keys_to_remove = memo.map(&:base).grep(/^#{Regexp.escape(item.base)}/).to_set
      memo << item
      memo.delete_if do |value|
        keys_to_remove.include?(value.base)
      end
      memo
    end
    QueryMatchResults.new(query: query, paths: matching_paths)
  end

  # Match types:
  #   a. simple path
  #   b. value filtering
  #   c. list index
  # TODO
  #   given the composition of each segments (path and query) we
  #   could perform a preliminary check to see if they don't match.
  def self.match_query_against_path(query:, path:, data_reference:)
    if path.segments.count < query.segments.count
      return false
    end
    query.segments.each_with_index.all? do |query_segment, segment_index|
      path_segment = path.segments[segment_index]
      query_segment_type = detect_query_segment_type(query_segment: query_segment)
      data_reference = case query_segment_type
      when :key
        key_based_match(
        query_segment: query_segment,
        path_segment: path_segment,
        data_reference: data_reference
        )
      when :value_filter
        value_filter_based_match(
        query_segment: query_segment,
        path_segment: path_segment,
        data_reference: data_reference
        )
      when :list_index
        list_index_based_match(
        query_segment: query_segment,
        path_segment: path_segment,
        data_reference: data_reference
        )
      else
        # shouldn't happen
        nil
      end
    end
  end

  # path ~ key
  def self.key_based_match(query_segment:, path_segment:, data_reference:)
    if path_segment.match(/.*#{query_segment}.*/i)
      data_reference[path_segment]
    else
      false
    end
  end

  # query := path[key_1=value_1&key_2=value_2]
  # .*.path[i].{key_1, key_2} ~ {value_1, value_2}
  def self.value_filter_based_match(query_segment:, path_segment:, data_reference:)
    # "accounts[2]", _
    # path_segment, path_segment_index

    # query: goog.acc[na=mau].pass
    # path: google.accounts[2].password : google.accounts[2].name == "mau"

    # "acc", "na=mau"
    query_key, query_filters = query_segment.match(/(.*)\[(.*)\]/).captures
    # match groups: ["accounts", "2"]
    results = path_segment.match(/(.*#{query_key}.*)\[([0-9]+)\]/i)
    if !results
      return false
    end
    # "accounts", "2"
    path_key, path_index = results.captures
    if !Data::is_list?(data_reference[path_key])
      return false
    end
    data_reference = data_reference[path_key][path_index.to_i]
    if !Data::is_set?(data_reference)
      return false
    end
    conditions = query_filters.split("&")
    if conditions_verified_in_data_reference?(conditions: conditions, data_reference: data_reference)
      data_reference
    else
      false
    end
  end

  # data_reference[key][i]?
  def self.list_index_based_match(query_segment:, path_segment:, data_reference:)
    query_key, query_index = query_segment.match(/(.*)\[([0-9]+)?\]/).captures
    if !path_segment.match(/(.*#{query_key}.*)\[#{query_index || ".*"}\]/i)
      return false
    end
    path_key, path_index = path_segment.match(/^(.*)\[([0-9]+)\]$/).captures
    if !Data::is_list?(data_reference[path_key])
      return false
    end
    path_index = path_index
    if data_reference[path_key].count < path_index.to_i
      return false
    end
    data_reference[path_key][path_index.to_i]
  end

  # :value_filter => "key=value"
  # :list_index   => "key[]", "key[i]"
  # :key          => "key"
  def self.detect_query_segment_type(query_segment:)
    case query_segment
    when /^.*\[.*=.*\]$/ then :value_filter
    when /^.*\[.*\]$/ then :list_index
    else
      :key
    end
  end

  # for each condition := "key=value", data_reference[key] ~ value
  def self.conditions_verified_in_data_reference?(conditions:, data_reference:)
    conditions.all? do |condition|
      condition_key, condition_value = condition.split("=")
      sub_path_key = data_reference.keys.grep(/^.*#{condition_key}.*$/i).first
      if !sub_path_key
        return false
      end
      sub_data_reference = data_reference[sub_path_key]
      if Data::is_set?(sub_data_reference) || Data::is_list?(sub_data_reference)
        return false
      end
      sub_data_reference.match(/.*#{condition_value}.*/i)
    end
  end

end
