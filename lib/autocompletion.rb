# encoding: utf-8



require 'autocompletion/version'



# AutoCompletion
# A binary search for prefix-matching is used to determine left- and right-
# boundary. This means even with 1_000_000 items, a maximum of 40 comparisons
# is required.
#
# @example Autocomplete words
#     auto = AutoCompletion.words(%w[foo bar baz])
#     auto.complete('f') # => ["foo"]
#     auto.complete('b') # => ["bar", "baz"]
#     auto.complete('z') # => []
#
# @example Autocomplete objects by attributes
#     Person  = Struct.new(:first_name, :last_name)
#     people  = [
#       Person.new("Peter", "Parker"),
#       Person.new("Luke", "Skywalker"),
#       Person.new("Anakin", "Skywalker"),
#     ]
#     auto    = AutoCompletion.map_keys(people) { |person|
#       [person.first_name, person.last_name]
#     }
#
#     auto.complete("P")
#     # => [#<struct Person first_name="Peter", last_name="Parker">]
#
#     auto.complete("S")
#     # => [#<struct Person first_name="Luke", last_name="Skywalker">,
#     #     #<struct Person first_name="Anakin", last_name="Skywalker">]
#
#     auto.complete("S", "L")
#     # => [#<struct Person first_name="Luke", last_name="Skywalker">]
class AutoCompletion

  # Raised by AutoCompletion::new
  class InvalidOrder < ArgumentError
    def initialize
      super("The prefixes are not in sorted order")
    end
  end

  # @return [AutoCompletion]
  #   An autocompletion for a list of words.
  def self.words(words)
    unordered_tuples(words.map { |word| [word, word] })
  end

  # @return [AutoCompletion]
  #   Map a list of entities to many of their attributes.
  #   The block should return an array of strings which can be prefix-searched.
  def self.map_keys(entities)
    mapped = entities.flat_map { |entity|
      keys = yield(entity)
      keys.flat_map { |key| [key, entity] }
    }

    unordered_tuples(mapped.each_slice(2))
  end

  # @return [AutoCompletion]
  #   Map a list of entities to one of its attributes.
  #   The block should return string which can be prefix-searched.
  def self.map_key(entities)
    mapped = entities.map { |entity|
      [yield(entity), entity]
    }

    unordered_tuples(mapped)
  end

  # @return [AutoCompletion]
  #   Creates an AutoCompletion for an unordered array of the form [["prefix", value], …].
  def self.unordered_tuples(entities)
    new(entities.sort_by(&:first).flatten(1), true)
  end

  # All stored entities. A flat array of the form [prefix1, value1, prefix2, value2, …]
  attr_reader :entities

  # @param [Array<Array>] entities
  #   A flat array of the form [prefix1, value1, prefix2, value2, …] containing all
  #   prefixes and their corresponding value.
  # @param [Boolean] force
  #   If force is set to true, the order of entities is not verified. Use this only if
  #   you know what you're doing.
  #
  # @see AutoCompletion::words, AutoCompletion::map
  def initialize(entities, force=false)
    @entities = entities
    raise InvalidOrder unless force || valid?
  end

  # @return [Boolean]
  #   Returns true if the prefixes are in a valid order.
  def valid?
    @entities.each_slice(2).each_cons(2).all? { |(a,_),(b,_)|
      a <= b
    }
  end

  # @return [Boolean]
  #   Returns true if there are no prefixes stored in this AutoCompletion instance.
  def empty?
    @entities.empty?
  end

  # @return [Integer]
  #   The number of prefixes stored. Note that the same prefix can occur multiple times.
  def size
    @entities.size>>1
  end

  # @return [Integer] The number of distinct entities
  def count_distinct_entitites
    result = {}
    @entities.each_slice(2) do |key, value|
      result[value] = true
    end

    result.size
  end

  # @return [Integer] The number of distinct prefixes
  def count_distinct_prefixes
    result = {}
    @entities.each_slice(2) do |key, value|
      result[key] = true
    end

    result.size
  end

  # @param [String] prefixes
  #   A list of prefixes to match. All given prefixes must be matched.
  #
  # @return [Array]
  #   Returns an array of distinct entities matching the given prefixes.
  def complete(*prefixes)
    # short-cut
    return [] if empty? || prefixes.empty? || prefixes.any? { |word|
      word < @entities.first[0,word.size] || word > @entities[-2][0,word.size]
    }

    slices = prefixes.map { |word|
      slice = range_search(word)
      return [] unless slice # short-cut

      slice
    }

    result = @entities[slices.pop].each_slice(2).map(&:last).uniq
    slices.each do |slice|
      result &= @entities[slice].each_slice(2).map(&:last)
    end

    result
  end

  # @return [nil, Range<Integer>]
  #   Returns nil if AutoCompletion#empty?
  #   Returns -1..-1 if the prefix is smaller than the smallest key
  #   Returns AutoCompletion#size..AutoCompletion#size if the prefix is bigger than the biggest key
  #   Returns the range for all matched keys and values otherwise
  def range_search(prefix)
    prefix_size   = prefix.size
    length        = size()
    found         = nil
    left          = 0
    right         = length-1
    found         = false
    max_exc_right = length

    return nil if empty?
    return -1..-1 if @entities[0][0,prefix_size] > prefix # prefix is smaller than smallest value
    return length..length if @entities[-2][0,prefix_size] < prefix # prefix is bigger than biggest value

    # binary search for smallest index
    # mark biggest right which includes prefix, and biggest mark that doesn't include prefix
    while(left<right)
      index     = (left+right)>>1
      cmp_value = @entities.at(index<<1)[0,prefix_size]
      case cmp_value <=> prefix
        when -1 then
          left          = index+1
        when 1 then
          right         = index
          max_exc_right = right
        else # 0
          right         = index
      end
    end
    return nil unless @entities.at(left<<1)[0,prefix_size] == prefix
    final_left = left

    # binary search for biggest index
    right = max_exc_right-1
    while(left<right)
      index     = (left+right)>>1
      cmp_value = @entities.at(index<<1)[0,prefix_size]
      if cmp_value > prefix then
        right = index
      else
        left = index+1
      end
    end
    final_right = right
    final_right -= 1 unless @entities.at(right<<1)[0,prefix_size] == prefix

    return (final_left<<1)..((final_right<<1)+1)
  end
end
