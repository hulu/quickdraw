# Functions related to contexts
qdInternal.context = {
    # Creates a binding context that can be used for a binding function
    # If this viewmodel has a parental hirearchy the binding context
    # will reflect this relationship.
    # The returned binding context has the following values
    #   $data - the view model unwrapped if it is observable
    #   $rawData - the raw view model still wrapped if it is observable
    #   $parents - an array of parent view models
    #   $parent - the direct parent view model to the given one, null if none
    #   $parentContext - a binding context created for the parent view model
    #   $root - the root view model, i.e. the topmost context
    #   $extend - a function that can be called with a viewmodel meant to be
    #              the child of the given which will create a new properly
    #              extended context for that child
    # @param [Object] viewModel the model to base the context off
    # @return [Object] a complete binding context for evaluation
    create : (viewModel) ->
        # check if this viewmodel already has a context, reuse if so
        if viewModel.__context?
            return viewModel.__context

        # extending function for object
        extend = (child) ->
            child = qdInternal.models.create(child)
            rawChildModel = qdInternal.models.unwrap(child)
            # store context on child so it has a complete one to rebind with
            child.__context = {
                $data : qd.unwrapObservable(rawChildModel)
                $rawData : rawChildModel
                $parents : [@.$data].concat(@.$parents)
                $parent : @.$data
                $parentContext : @
                $root : @.$root
                $extend : extend
            }
            return child.__context

        # construct original parents
        parents = []
        parentModels = []
        current = viewModel
        while (parent = qdInternal.models.getParent(current))?
            parentModels.push(parent)
            parents.push(parent.raw)
            current = parent

        # new object
        viewModel.__context = {
            $data : qd.unwrapObservable(viewModel.raw)
            $rawData : viewModel.raw
            $parents : parents
            $parent : parents[0] ? null
            $parentContext : parentModels[0]?.__context ? null
            $root : qd.unwrapObservable(parents[parents.length - 1] ? viewModel.raw)
            $extend : extend
        }

        return viewModel.__context

    # Get the binding context used on a dom node if there was one
    # @param [DomElement] domNode the node to get the context for
    # @return [Context] the complete binding context if this node has been bound before
    #                   null if the given node hasn't been bound before
    get : (domNode) ->
        baseViewModel = qdInternal.storage.getInternalValue(domNode, qd.getConfig('baseModelKey'))
        return null unless baseViewModel?
        return @create(baseViewModel)

    # Sets the binding context for a given dom node
    # @param [DomElement] domNode the node to set the context for
    # @param [Context] context the binding context that should be stored for this node
    set : (domNode, context) ->
        qdInternal.storage.setInternalValue(domNode, qd.getConfig('baseModelKey'), context)
        # void the return
        return


}