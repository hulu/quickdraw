# A set of helpers to define eventing methods on objects
qdInternal.eventing = {

    # Add event registration method to the object
    # @param [String] eventType the type of event
    # @param [Function] callback the callback to call
    _on : (eventType, callback) ->
        registrations = @__eventRegistrations ?= {}

        registrations[eventType] ?= []
        registrations[eventType].push(callback)

        # dont return array
        return

    # Adds an event registration that will only be called once
    # and after called it will unregister
    # @param [String] eventType the type of event
    # @param [Function] callback the callback to call
    _once : (eventType, callback) ->
        wrappedCallback = (args...) =>
            callback.apply(@, arguments)
            @removeListener(eventType, wrappedCallback)

        # register through previous handler
        @on(eventType, wrappedCallback)

        # dont return registration
        return

    # Remove event registration method from the object
    # @param [String] eventType the type of event
    # @param [Function] callback the callback to call
    _removeListener : (eventType, callback) ->
        registrations = @__eventRegistrations

        if registrations?[eventType]?
            # remove the callback
            registrations[eventType] = (reg for reg in registrations[eventType] when reg isnt callback)

        # dont return result
        return

    # Emit an event on this object
    # @param [String] eventType the type of event to emit
    # @param [Array] args a set of arguments to pass
    # @param [Boolean] async whether or not to perform this emit async
    _emit : (eventType, args, async = true) ->
        # only attempt an emit if registrations exist
        return unless @__eventRegistrations? and @__eventRegistrations[eventType]?

        # capture the callback array so callbacks can be removed
        # while traversing and not affect the loop
        callbacks = @__eventRegistrations[eventType]
        emitCallback = =>
            for callback in callbacks
                callback.apply(@, args)

            # prevent return
            return

        if async
            qdInternal.async.immediate(emitCallback)
        else
            emitCallback()

        # prevent return catch
        return

    # Takes the given element and adds the eventing methods to it
    # @param [Object] obj an object to add eventing methods to
    add : (obj) ->
        evt = qdInternal.eventing

        # Map methods to the object, they use `this` references to access the
        # registrations so new closures are not generated every time.
        # 
        # Notice we are not creating the registrations object, this will be
        # created on demand to avoid unnecessary object creation.
        obj.on = evt._on
        obj.once = evt._once
        obj.removeListener = evt._removeListener
        obj.emit = evt._emit

        # return object for convenience but not necessary
        return obj
        
}

# add eventing directly to quickdraw
qdInternal.eventing.add(qd)
