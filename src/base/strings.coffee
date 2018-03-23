# A set of methods and objects that can be used to manipulate strings
qdInternal.strings = {
    # Appends to a string to another string using the delimiter specified
    # If the first string already ends in the given delimiter then the
    # delimiter is not added again.
    # @param [String] string the base string to add to
    # @param [String] item the item to append to the string
    # @param [Char] delimiter a single character to act as a delimiter
    # @return appropriate equivalent to string + delimiter + item
    appendWithDelimiter : (string, item, delimiter) ->
        result = string
        if result.length > 0 and result[result.length - 1] isnt delimiter
            result += delimiter
        result += item
        return result

    # A tokenizer class that can be used to extract tokens from a string
    # that are separated by a single character delimiter. The delimiter
    # can be repeated any number of times between tokens, all instances
    # will be stripped
    tokenizer : class
        # Construct a new tokenizer that is based on the given string
        # and delimiter
        # @param [String] string the string to tokenize
        # @param [Char] delimiter the delimiter that will separate tokens
        constructor: (@string, @delimiter) ->
            @pos = 0

        # Gets the next token in the string if available
        # @return The next token if there is one, null otherwise
        nextToken: ->
            unless @string?
                return null

            while @string[@pos] is @delimiter and @pos < @string.length
                ++@pos

            nextpos = @pos
            while nextpos < @string.length and @string[nextpos] isnt @delimiter
                ++nextpos

            if nextpos > @pos
                token = @string.substring(@pos, nextpos)
                @pos = nextpos
                return token

            return null

        # Calls the given callback for every token in the string
        # After calling this the tokenizer will always return null
        # from nextToken
        # @param [Function] callback to call with each token
        map: (callback) ->
            while (nextToken = @nextToken()) isnt null
                callback(nextToken)

            # dont capture return
            return

        # Converts the remaining tokens in the string to an array 
        # of tokens. After calling this the tokenizer will return 
        # null from nextToken
        # @return array of remaining tokens from tokenizer
        #         tokens are in the order they appear in the string
        toArray: ->
            values = []
            @map((token) -> values.push(token))
            return values
}
