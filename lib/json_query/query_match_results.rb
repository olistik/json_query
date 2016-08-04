module JsonQuery
  class QueryMatchResults
    attr_reader :query, :paths
    def initialize(query:, paths: [])
      @query, @paths = query, paths
    end

    def has_matching_paths?
      paths.any?
    end
  end
end
