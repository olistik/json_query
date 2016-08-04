module JsonQuery
  class CompositeQuery
    attr_reader :base, :segments
    def initialize(base: "", segments: [])
      @base, @segments = base, segments
    end
  end
end
