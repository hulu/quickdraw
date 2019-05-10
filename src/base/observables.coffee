# Define internal observable functions
qdInternal.observables = {
    # Adds a dom element and view model as a dependency to this observable
    # @param [Object] model the model that is used for the context of the element
    # @param [DomElement] element the element that is being updated
    # @param [String] handler the name of the handler accessing this observable
    addDependency : (model = qdInternal.state.current.model, element = qdInternal.state.current.element, handler = qdInternal.state.current.handler) ->
        return unless model? and element?
        # unwrap the element in case its virtual
        element = qdInternal.dom.unwrap(element)

        # store model on dom element, may overrite previous models, this is fine
        # elements should only be bound to one model anyways
        qdInternal.context.set(element, model)

        @__dependencies ?= []

        # Add element to observable dependencies
        matchingElms = @__dependencies.filter((elm) -> return elm.domNode is element)
        if matchingElms.length > 0
            dependencyObject = matchingElms[0]
        else
            dependencyObject = {
                domNode : element
                handlers : []
            }
            @__dependencies.push(dependencyObject)
            # bound to a new element, alert listeners
            @emit('bound', [model, element])

        # If a handler is defined, specify it in the handlers
        if handler?
            # if the current handler is not in the list of handlers, add it
            if handler not in dependencyObject.handlers
                dependencyObject.handlers.push(handler)
        else
            # observable unwrapped in raw binding object, we cant tie it to a specific handler
            dependencyObject.unspecific = true

        # Add observable to the dom element that is being updated
        observables = qdInternal.storage.getInternalValue(element, 'observables') ? []
        if @ not in observables
            observables.push(@)
        qdInternal.storage.setInternalValue(element, 'observables', observables)

        # dont return result
        return

    # Adds a computed as a dependent to this observable
    # @param [QDComputed] computed the computed that depends on the observable
    addComputedDependency : (computed) ->
        @__computedDependencies ?= []

        # Add to observable if necessary
        if computed not in @__computedDependencies
            @__computedDependencies.push(computed)

        return

    # Gets the dependencies for an observable
    # @note this will contain any nodes that are dependent directly or via computeds
    # @return [Array] the dom elements that are dependent on this observable
    getDependencies : ->
        # get base direct dependencies
        dependencies = @__dependencies ? []

        # get the dependencies as a result of computeds
        for computed in (@__computedDependencies ? [])
            dependencies = dependencies.concat(qdInternal.observables.getDependencies.call(computed))

        return dependencies

    # Removes the given dom element as a dependency from this observable
    # @param [DomNode] element the dom node to remove
    removeDependency : (element) ->
        # ensure virtual elements are unwrapped
        element = qdInternal.dom.unwrap(element)

        @__dependencies = (dependency for dependency in @__dependencies when dependency.domNode isnt element)
        @emit('unbound', [element])
        return

    # Returns whether or not this observable has any type of dependency
    # @return [Boolean] whether or not the observable has any dependencies
    hasDependencies : ->
        return qdInternal.observables.getDependencies.call(@).length > 0

    # Causes an update to happen for the dependencies of this observable
    updateDependencies : (immediate = false) ->
        dependencies = qdInternal.observables.getDependencies.call(@)
        # only update if there are dependencies
        return unless dependencies.length > 0

        immediateRebinds = []

        # traverse through the registered dependencies
        for dependency in dependencies
            element = dependency.domNode

            # mark all the dependent handlers dirty on the node
            handlers = qdInternal.storage.getInternalValue(element, 'handlers')

            # todo, fix bug where handlers doesnt exist but handler is specific
            continue unless handlers

            if dependency.unspecific
                # observable must refresh all handlers because it was not specific enough
                for handler of handlers
                    handlers[handler] = true
            else
                # observable can be specific
                for handler in dependency.handlers
                    handlers[handler] = true

            if immediate
                immediateRebinds.push(element)
            else
                # enqueue this element for updates
                qdInternal.updates.enqueue(element)

        if immediate
            # If immediate update requested process all nodes now
            qdInternal.updates.updateNodeSet(immediateRebinds)

            # trigger a bind render now, note we have to render the entire queue because of strict ordering
            qdInternal.renderer.render()
        else
            # schedule an update to occur
            qdInternal.updates.schedule()

        # emit a set value event since a change has occurred
        @emit('set')

        return

    # These functions will be aliased to the observables we create
    # but they use the 'this' value to reference any necessary state
    # so that they can be defined once and used many times
    helpers : {
        # General Observable Helpers

        # Immediately updates the current observables dependencies
        immediate: (newValue) -> return @(newValue, true)

        # Silently updates the current observables dependencies
        silent: (newValue) -> return @(newValue, false, false)

        # so that observables can be properly unpacked but still have simple negation
        # we will expose a 'secondary' observable under the 'not' attribute
        not: (newValue, immediate, alertDependencies) -> return not @(newValue, immediate, alertDependencies)

        # Array Observable Helpers
        indexOf: (find) ->
            for item, i in @value
                if item is find
                    return i
            return -1

        slice: ->
            ret = @value.slice.apply(@value, arguments)
            qdInternal.observables.updateDependencies.call(@)
            return ret

        push: (item) ->
            @value.push(item)
            qdInternal.observables.updateDependencies.call(@)
            return

        pop: ->
            ret = @value.pop()
            qdInternal.observables.updateDependencies.call(@)
            return ret

        unshift: (item) ->
            @value.unshift(item)
            qdInternal.observables.updateDependencies.call(@)
            return

        shift: ->
            ret = @value.shift()
            qdInternal.observables.updateDependencies.call(@)
            return ret

        reverse: ->
            @value.reverse()
            qdInternal.observables.updateDependencies.call(@)
            return

        sort: (func) ->
            @value.sort(func)
            qdInternal.observables.updateDependencies.call(@)
            return

        splice: (first, count, elements...) ->
            ret = @value.splice(first, count, elements...)
            qdInternal.observables.updateDependencies.call(@)
            return ret

        remove: (find) ->
            newBack = []
            removed = []
            for item in @value
                # if find is a callback call it, otherwise compare
                drop = (find?(item) ? (item is find))

                # add to appropriate array
                (if drop then removed else newBack).push(item)

            @value = newBack
            qdInternal.observables.updateDependencies.call(@)
            return removed

        removeAll: (items) ->
            removed = []
            if items?
                newBack = []
                for item in @value
                    if item in items
                        removed.push(item)
                    else
                        newBack.push(item)
                @value = newBack
            else
                removed = @value
                @value = []
            qdInternal.observables.updateDependencies.call(@)
            return removed
    }

    extendFunctions : (obs) ->
        # Mark this as observable
        obs.isObservable = true

        # expose some helpers externally
        obs.isBound = @hasDependencies
        obs.immediate = @helpers.immediate
        obs.silent = @helpers.silent
        obs.addComputedDependency = @addComputedDependency

        # since not can be passed alone in a binding string we
        # need to pass a closure, this will be removed once not
        # is no longer an attached property
        obs.not = => @helpers.not.apply(obs, arguments)

        obs.not.isObservable = true

        # make observables support eventing
        qdInternal.eventing.add(obs)

        # return our newly completed observable
        return obs
}

# Constructs a new observable object that can be added to a raw data model
# @param [mixed] initialValue the value to start the observable at
# @return [QDObservable] a new observable ready to be bound
qd.observable = (initialValue) ->
    # The function base for the new observable
    obv = (newValue, immediate = false, alertDependencies = true) ->
        # If we are applying bindings and no model has been
        # set for this observable, set it
        if qdInternal.state.current.model?
            qdInternal.observables.addDependency.call(obv)

        # Check if we were given a new value, if so set it
        # and update any dependencies
        if typeof newValue isnt "undefined"
            obv.value = newValue
            # only alert updates if enabled
            if alertDependencies
                qdInternal.observables.updateDependencies.call(obv, immediate)
        else
            if alertDependencies
                # emit an access event synchronously so listeners can
                # modify the value if they want
                obv.emit('access', [], false)
                # emit an accessed event so listeners can know it was used
                obv.emit('accessed')

        # Return the current value
        return obv.value

    # state values for the observable
    obv.value = initialValue
    return qdInternal.observables.extendFunctions(obv)

# Constructs a new computed object that will trigger updates on
# any of its dependencies whenever one of the observables it uses updates
# @param [Function] computedValue the function that computes a value
# @param [Object] thisBinding the value to bind as 'this' for calls to computedValue
# @param [Array] observables an array of observables that the computed depends on
qd.computed = (computedValue, thisBinding, observables) ->
    unless thisBinding?
        qdInternal.errors.throw(new QuickdrawError("Creating computed without specifying the appropriate this context to evaluate in"))

    if not observables? or observables.length is 0
        qdInternal.errors.throw(new QuickdrawError("Creating computed without specifying the appropriate observables the computed uses"))

    # The function that we will hand back for users to call
    compute = (params...) ->
        # If we are applying bindings and no model has been
        # set for this observable, set it
        if qdInternal.state.current.model?
            qdInternal.observables.addDependency.call(compute)

        # Call the real function with the given arguments
        return computedValue.apply(thisBinding, params)

    # Register this as a dependency to the given observables
    for observe in observables
        # If observe is undefined we do not add the computed dependency as there is nothing to add it to.
        # If added without a valid observable, this would cause a memory leak as the computedDependency
        # is attached to the window instead of the observable, thus making it a very difficult reference
        # to remove.
        unless observe?
            qdInternal.errors.throw(new QuickdrawError("Creating computed with undefined or null observables is not allowed"))
            continue

        qdInternal.observables.addComputedDependency.call(observe, compute)

    return qdInternal.observables.extendFunctions(compute)

# Constructs a new observable array object that functions just like
# a javascript array (except the bracket operators) but has the benefit
# of being able to update the UI on changes
# @param [Array] initialValue the value to start the observable with, defaults to empty array
# @return [QDObservableArray] a new observable ready to be bound
qd.observableArray = (initialValue = []) ->
    # at the heart observable arrays are just observables
    arr = qd.observable(initialValue)

    # but we add some nice helper functions to manipulate arrays
    # without the need to unpack them and also extend their functionality
    helpers = qdInternal.observables.helpers
    arr.indexOf = helpers.indexOf
    arr.slice = helpers.slice
    arr.push = helpers.push
    arr.pop = helpers.pop
    arr.unshift = helpers.unshift
    arr.shift = helpers.shift
    arr.reverse = helpers.reverse
    arr.sort = helpers.sort
    arr.splice = helpers.splice
    arr.remove = helpers.remove
    arr.removeAll = helpers.removeAll

    return arr

# Checks whether or not a given value is an observable
# @param [Mixed] value a possible observable
# @return [Boolean] true if value is an observable, false otherwise
qd.isObservable = (value) ->
    # force coercion to boolean
    return !!(value?.isObservable)

# @param [mixed] possible a value that could be an observable
# @param [Boolean] recursive if the unwrapped value is an object any properties
#                            of the object will be recursively unwrapped
# @note a recursive unwrapping will yield a new object so the results of multiple
#       calls cannot be used with direct comparisons
# @return If the value given is an observable returns the wrapped value
#         If the value given is not an observable, just that value
qd.unwrapObservable = (possible, recursive = false) ->
    # handle null case upfront
    return possible unless possible?

    unwrapped = possible
    if qd.isObservable(possible)
        unwrapped = possible.silent?() ? possible()

    # again handle a null value within an observable/computed
    # note: typeof null == 'object'
    return unwrapped unless unwrapped?

    # if this value can be recursively unwrapped and that was
    # requested, do it now
    if recursive and typeof unwrapped is 'object'

        if Object::toString.call(unwrapped) is '[object Array]'
            recursed = new Array(unwrapped.length)
            for value, index in unwrapped
                # unwrap the value and recurse if it is also an object
                recursed[index] = qd.unwrapObservable(value, true)
        else
            recursed = {}
            for key, value of unwrapped
                # unwrap the value and recurse if it is also an object
                recursed[key] = qd.unwrapObservable(value, true)

        unwrapped = recursed

    return unwrapped
