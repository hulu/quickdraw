# Pieces of quickdraw that deal with binding handler registration
qdInternal.handlers = {
    # Gets the initialize method for the handler associated with the given keyword
    # @param [String] keyword the handler keyword to look for
    # @return [Function] the initialize for the handler if there is one
    #                    null otherwise
    getInitialize : (keyword) ->
        return qdInternal.state.binding.handlers[keyword]?.methods.initialize ? null

    # Gets the update method for the handler associated with the given keyword
    # @param [String] keyword the handler keyword to look for
    # @return [Function] the update method for the hanlder if there is one
    #                    null otherwise
    getUpdate : (keyword) ->
        return qdInternal.state.binding.handlers[keyword]?.methods.update ? null

    # Gets the cleanup method for the handler associated with the given keyword
    # @param [String] keyword the handler keyword to look for
    # @return [Function] the cleanup method for the handler if there is one
    #                    null otherwise
    getCleanup : (keyword) ->
        return qdInternal.state.binding.handlers[keyword]?.methods.cleanup ? null

    # @return [Boolean] whether or not a given handler exists
    exists : (keyword) ->
        return qdInternal.state.binding.handlers[keyword]?
}

# Registers a binding handler with the quickdraw system
# the binding handler will be used in all calls to bindModel
# following the call to this function
# @param [Object] keyword  the keyword users specify to trigger this handler
# @param [Object] handler  the handler object with bound/update/unbound callbacks
#                          that will handle dom objects
# @param [Boolean] override  flag to permit the handler to override an existing handler
# @throws Exception if given keyword has already been registered
qd.registerBindingHandler = (keyword, handler, follows = [], override = false) ->
    unless keyword? and keyword.length > 0
        return qdInternal.errors.throw(new QuickdrawError("Binding handler must have a valid name"))

    if qdInternal.handlers.exists(keyword) and not override
        return qdInternal.errors.throw(new QuickdrawError("Binding handler already registered for '#{keyword}'"))

    # enforce requirement of at least an initialize or update callback
    unless handler.initialize? or handler.update?
        return qdInternal.errors.throw(new QuickdrawError("A binding handler must at least specify an 'initialize'/'update' callback"))

    # bind the qdInternal variable to the this argument of the handlers
    for type in ['initialize', 'update', 'cleanup']
        continue unless handler[type]?
        handler[type] = do (type, callback = handler[type]) ->
            return (args...) ->

                stateMemento = qdInternal.updateCurrentState({
                    handler : keyword
                })

                try
                    result = callback.apply(qdInternal, args)
                catch err
                    # these two handlers pass the node as the second argument
                    if type in ['initialize', 'update']
                        node = args[1]
                    # cleanup passes the node as the only argument
                    else
                        node = args[0]
                    error = new QuickdrawError("Error in '#{type}' of '#{keyword}' binding handler: \"#{err.message}\"", err)
                    error.setDomNode(node)
                    qdInternal.errors.throw(error)
                finally
                    # restore the previous state before this function call
                    stateMemento()

                return result

    # grab reference to the handlers storage
    handlers = qdInternal.state.binding.handlers

    # return updated object
    handlers[keyword] = {
        methods : handler
        follows : follows
    }

    # update the binding handler execution order
    toProcess = []
    dependencyMap = {}
    dependencyCount = {}
    for name, handler of handlers
        valid = 0
        for precursor in handler.follows
            # if the specified precursor hasnt been registered, skip it
            continue unless handlers[precursor]?

            # add this handler to the dependency map for the precursor
            dependencyMap[precursor] ?= []
            dependencyMap[precursor].push(name)
            valid++

        if valid is 0
            # if there were no valid precursors this handler can be processed immediately
            toProcess.push(name)
        else
            # otherwise store its dependency count
            dependencyCount[name] = valid

    # now order the handlers based on their described dependencies
    handlerOrder = qdInternal.state.binding.order
    handlerOrder.length = 0
    while toProcess.length > 0
        name = toProcess.shift()
        # add the handler to the dependency order
        handlerOrder.push(name)

        # go through any handlers dependent on it being
        # ordered and decrement their dependency count
        # if their count has reached 0 go ahead and add
        # that handler to the list of handlers that need processing
        for handler in dependencyMap[name] ? []
            dependencyCount[handler]--
            if dependencyCount[handler] is 0
                toProcess.push(handler)

    return handlers[keyword].methods
