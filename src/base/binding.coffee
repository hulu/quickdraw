# Functions related to model/dom binding
qdInternal.binding = {

    # Parses the binding function associated with the given node
    # @param [DomElement] a node that could have a binding function
    # @return [mixed]  a function that can be called with an approrpriate context
    #                       if the given node does have a binding function
    #                  null if the given node does not have a binding function
    getBindingFunction : (node) ->
        # If a node cant have an attribute, exit
        unless node?.getAttribute?
            return null

        # grab the binding string from the node
        bindingString = node.getAttribute(qd.getConfig('bindingAttribute'))

        # if there is no binding string, no bindings necessary
        return null unless bindingString?

        # build a function if not already cached
        unless qdInternal.state.binding.functions[bindingString]?
            # build the binding function since we haven't before
            toParse = bindingString
            if bindingString.trim()[0] isnt '{'
                toParse = '{' + toParse + '}'

            #Reserved words not allowed as property names until ECMA 5
            toParse = toParse.replace(/(with|if)\s*:/g, '\'$1\' :')

            # notice we evaluate with the $context object, but this always
            # internally has a $data object, which we also want to bind with
            # so we can say $data directly inside and have the correct object
            # as it will look into the $context object to find the $data object
            functionBody = 'with($context) {' +
                           '    with($data) {' +
                           '        return ' + toParse +
                           '    }' +
                           '}';
            bindingFunction = null
            try
                bindingFunction = new Function('$context', '$element', functionBody)
            catch err
                error = new QuickdrawError("Error in parsing binding '#{toParse}', #{err.message}")
                error.setOriginalError(err)
                error.setDomNode(node)
                return qdInternal.errors.throw(error)
            qdInternal.state.binding.functions[bindingString] = bindingFunction

        # return the binding function
        return qdInternal.state.binding.functions[bindingString]

    # Gets the binding function for the given dom node and evaluates it in the given binding context
    # @param [VirtualDomNode] domNode the node to get the binding string of
    # @param [Object] bindingContext the context to use in evaluating the node
    # @return [Object] the result of the binding function if there is one, null otherwise
    getEvaluatedBindingObject : (domNode, bindingContext) ->
        # get the binding function for this node
        bindingFunction = @getBindingFunction(domNode)

        # if there is no binding function return now
        return null unless bindingFunction?

        try
            # pass the real dom node to the binding function as the $element value
            return bindingFunction(bindingContext, qdInternal.dom.unwrap(domNode))
        catch err
            error = new QuickdrawError("'#{err.message}' in binding '#{domNode.getAttribute(qd.getConfig('bindingAttribute'))}'", err)
            error.setBindingContext(bindingContext)
            error.setDomNode(domNode)
            qdInternal.errors.throw(error)
            return null

    # Applies a recursive binding with the given binding context
    # @note this should not be called from outside of quickdraw or a
    #       registered binding handler
    # @param [Object] viewModel a raw javascript object that contains
    #                           bindable attributes
    # @param [VirtualDomNode] domRoot     a root in the dom tree to bind to
    # @param [Object] context   the context to use when binding
    # @throw Exception if view model or dom root or context is null
    bindModel : (viewModel, domRoot, context) ->
        unless viewModel?
            return qdInternal.errors.throw(new QuickdrawError('Attempting binding of a null View Model'))
        unless domRoot?
            return qdInternal.errors.throw(new QuickdrawError('Attempting to bind to a null Dom Root'))
        unless context?
            return qdInternal.errors.throw(new QuickdrawError('Attempting binding with a null context'))
        unless qdInternal.models.isModel(viewModel)
            return qdInternal.errors.throw(new QuickdrawError('Internal binding called with non-qd view model, must use models.create'))

        # virtualize the dom node if its not already
        domRoot = qdInternal.dom.virtualize(domRoot)

        # store previous as this could be recursive
        qdInternal.models.setParent(viewModel, qdInternal.state.current.model)
        stateMemento = qdInternal.updateCurrentState({
            model : viewModel
        })

        # update the views that this view model is part of
        @bindDomTree(domRoot, context)

        # assert that viewModel is @_state.binding.model so that
        # we didnt jump out of a recursive without reseting
        if viewModel isnt qdInternal.state.current.model
            error = new QuickdrawError('After updating view, view model and applying bindings no longer match')
            error.setBindingContext(context)
            error.setDomNode(domRoot)
            error.setViewModel(viewModel)
            qdInternal.errors.throw(error)

        # revert to previous model
        stateMemento()

        # dont return model
        return

    # Binds the given element root with the given binding context
    # The children of the current element will be bound with the same
    # binding context unless a binding handler terminates the binding
    # @param [VirtualDomNode] a dom element with or without children to bind
    # @param [Object] a binding context to apply
    bindDomTree : (domRoot, bindingContext) ->
        # apply to the current node the binding context values
        if @bindDomNode(domRoot, bindingContext)
            # continue applying to children
            for child in domRoot.getChildren()
                @bindDomTree(child, bindingContext)

        # prevent loop capture
        return

    # Applys any applicable binding handlers to the given node using the given context
    # @param [VirtualDomNode] domRoot a dom element that may require binding
    # @param [Object] bindingContext  the context to be given to the binding function
    # @return  whether or not the child elements of this node should be parsed
    bindDomNode : (domNode, bindingContext) ->
        # keep track of whether or not we should continue binding beyond this node
        # typically this will be true, but it is possible for binding handlers to
        # handle the binding of children
        shouldContinue = true

        # update the current state
        stateMemento = qdInternal.updateCurrentState({
            element : domNode
            handler : null
        })

        # attempt to get the evaluated binding object for this node
        bindingObject = @getEvaluatedBindingObject(domNode, bindingContext)

        unless bindingObject?
            # no binding object restore the state and move on
            stateMemento()
            return shouldContinue

        # initialize all binding handlers on the node and mark them as dirty for updates
        handlers = {}
        for name in qdInternal.state.binding.order
            # skip this handler if the binding object doesnt have any value for it
            continue unless bindingObject.hasOwnProperty(name)

            initialize = qdInternal.handlers.getInitialize(name)
            initialize?(bindingObject[name], domNode, bindingContext)

            # add handler to list of used ones and mark it dirty to start
            handlers[name] = true

        # store the handlers that this node has for quick reference to dirty state
        qdInternal.storage.setInternalValue(domNode, 'handlers', handlers)

        # since all handlers were considered dirty, update the dom node
        # pass down our binding object so we don't have to evaluate the function twice
        shouldContinue = @updateDomNode(domNode, bindingContext, bindingObject)

        # restore the previous state
        stateMemento()

        return shouldContinue

    # For the given node it runs the update function of any handlers that have been
    # marked as dirty on the dom node.
    # @param [DomNode] domNode the node that should be updated
    # @param [Object] bindingContext the context that the node should be evaluated in
    # @param [Object] bindingObject (optional) this parameter allows an already evaluated
    #                               binding object to be used instead of the result of the
    #                               binding function on the node.
    # @return [Boolean] whether or not the caller needs to traverse to the child nodes
    # @note the usual case will not provide a bindingObject but it is provided by the
    # original binding phase to prevent double evaluation of binding functions
    updateDomNode : (domNode, bindingContext, bindingObject = null) ->
        # keep track of whether or not we should bind the children of this node
        shouldContinue = true

        # update the current state
        stateMemento = qdInternal.updateCurrentState({
            element : domNode
            handler : null
        })

        # get the binding object if its not already been defined
        bindingObject ?= @getEvaluatedBindingObject(domNode, bindingContext)

        unless bindingObject?
            # no binding object, restore the state and move on
            stateMemento()
            return shouldContinue

        # get the handlers for this node
        handlers = qdInternal.storage.getInternalValue(domNode, 'handlers')
        for handler in qdInternal.state.binding.order
            # only run the handler if it has been previously marked as dirty
            continue unless handlers.hasOwnProperty(handler)

            # get the update method for the handler
            update = qdInternal.handlers.getUpdate(handler)

            # run update for handler, capture the should continue value
            shouldContinue = (update?(bindingObject[handler], domNode, bindingContext) ? true) and shouldContinue

            # mark the handler as clean now that its been dealt with
            handlers[handler] = false

        # restore the previous state
        stateMemento()

        return shouldContinue

    # Recursively unbinds an entire dom tree from their associated model
    # @param [VirtualDomNode] domNode the node to start the unbind at
    unbindDomTree : (domNode) ->
        domNode = qdInternal.dom.virtualize(domNode)
        # remove the node from all observables it is registered for
        observables = qdInternal.storage.getInternalValue(domNode, 'observables') ? []
        for observable in observables
            qdInternal.observables.removeDependency.call(observable, domNode)

        # trigger the cleanups for any applied handlers
        # go backwards through the dependency order to allow dependent handlers
        # to cleanup before their precursor deletes necessary state
        boundHandlers = qdInternal.storage.getInternalValue(domNode, 'handlers') ? {}
        for handler in qdInternal.state.binding.order by -1
            continue unless boundHandlers.hasOwnProperty(handler)

            # cleanups only get the dom node
            cleanup = qdInternal.handlers.getCleanup(handler)
            cleanup?(domNode)

        # delete all quickdraw references on dom
        domNode.clearValues()

        # unbind the children
        for child in domNode.getChildren()
            @unbindDomTree(child)

        # void the return
        return

}

# Applies bindings within the view model to the given domRoot
# @param [Object] viewModel a raw javascript object that contains
#                           bindable attributes
# @param [Node] domRoot     a root in the dom tree to bind to
# @throw Exception if view model or dom root is null
qd.bindModel = (viewModel, domRoot) ->
    unless viewModel?
        return qdInternal.errors.throw(new QuickdrawError("Bind model called with null view model"))

    # wrap viewmodel to quickdraw model, externally these are never seen
    viewModel = qdInternal.models.create(viewModel)
    baseContext = qdInternal.context.create(viewModel)
    qdInternal.binding.bindModel(viewModel, domRoot, baseContext)

    # clear the template cache now that binding is complete
    qdInternal.templates.clearCache()

    # schedule changes to the dom to be rendered
    qdInternal.renderer.schedule()

    # dont return result
    return


# Unbinds the given dom node by removing all model references from
# it and removing it as a dependency from any observables
# @note this will recursively unbind
# @param [DomNode] domRoot  a dom node that has been previously bound
qd.unbindModel = (domRoot) ->
    return unless domRoot?

    # Unbind the tree
    qdInternal.binding.unbindDomTree(domRoot)

    # void the return and prevent loop captures
    return
