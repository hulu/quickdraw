qdInternal.cache = {
    # Constructs a new simple caching object that will cache items
    # based on an id string and when a cached item is not available
    # it will call the given generator function with the id
    #
    # @note the cache is completely self contained, losing all references 
    #       to it will correctly clean it up
    #
    # @param [Function] generator a function that will return a cacheable object given an id
    # @param [Integer] cacheSize the max number of items to cache for any single id
    # @return [Object] a pool object with get/put/clear functions defined
    create : (generator, cacheSize = qd.getConfig('defaultCacheSize')) ->
        return {
            _cache : {}

            # Returns a useable result that is associated with the given id
            # if the id has an object available in the cache then the cache
            # will be used otherwise a new object weill be generated
            # @param [String] id the id associated with a common cache set
            # @return [Object] an object associated with the given id
            get : (id, args...) ->
                # if there are no templates in the cache, ask for a new one
                if (@_cache[id]?.length ? 0) is 0
                    return generator(id, args...)

                # return an item from the cache
                return @_cache[id].shift()

            # Returns an object to the cache after it is no longer in use
            # This assumes this object has been completely cleaned and can
            # be correctly reused.
            # @note if the cache size has been reached the object will be discarded
            # @param [String] id the id associated with the given object
            # @param [Object] object the object to add back to the cache
            put : (id, object) ->
                @_cache[id] ?= []
                if @_cache[id].length < cacheSize or cacheSize is -1
                    @_cache[id].push(object)

                # prevent cache exposure
                return
            
            # Clears out the current pool cache
            clear : ->
                @_cache = {}
                # don't expose the cache
                return
        }
}