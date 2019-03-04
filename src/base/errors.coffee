# Functions related to error handling in quickdraw
qdInternal.errors = {
    # Handles an error that has occurred in the system. If
    # a custom error handler has registered then it will be
    # triggered, otherwise the given error will be thrown
    # @note if an error is not a QuickdrawError it will be
    # wrapped
    # @param [Mixed] error a descriptive error object
    throw : (error) ->
        if qdInternal.state.error.handlers.length is 0
            throw error

        # if there are registered handlers, call them all
        for handler in qdInternal.state.error.handlers
            handler(error)
        # dont return the call results
        return
}

# A custom error class that can be used to provide stateful
# error information from within quickdraw when an error occurs
qdInternal.errors.QuickdrawError = class QuickdrawError
    constructor: (message, originalError) ->
        @message = message

        # Additional information
        @_current = {
            nodePath : null
            duringBinding : qdInternal.state.current.element isnt null
            error : originalError
            context : null
            observable : null
            domNode : qdInternal.dom.unwrap(qdInternal.state.current.element ? null)
            handler : qdInternal.state.current.handler ? null
            viewModel : qdInternal.models.unwrap(qdInternal.state.current.model) ? null
        }

    # If quickdraw caught an error and is sending it along, store
    # the original error so it can be accessed (if applicable)
    # @param [Error] error the original error that occurred
    setOriginalError: (error) ->
        @_current.error = error
        return

    # Set the binding context the error occurred in (if applicable)
    # @param [Context] context the binding context in  which the error occurred
    setBindingContext: (context) ->
        @_current.context = context
        return

    # Set the dom node that was in use during the error (if applicable)
    # @param [DomNode] domNode in use during the error
    setDomNode: (domNode) ->
        @_current.domNode = qdInternal.dom.unwrap(domNode)
        return

    # Set the observable that caused this error (if applicable)
    # @param [QDObservable] observable that caused the error
    setObservable: (observable) ->
        @_current.observable = observable
        return

    # Set the view model that caused this error (if applicable)
    # @param [QDModel] viewModel the model in use during the error
    setViewModel: (viewModel) ->
        return unless viewModel?
        @_current.viewModel = qdInternal.models.unwrap(viewModel)
        return

    # Set the node parent path of the node throwing this error (if applicable)
    # @param [String[]] nodePath array of node identifiers
    setNodePath: (nodePath) ->
        @_current.nodePath = nodePath
        return

    # @return [Object] all known details about the error
    errorInfo: ->
        return @_current

# Registers a given callback to be notified when an error occurs
# @param [Function] callback the function that will handle errors
qd.registerErrorHandler = (callback) ->
    qdInternal.state.error.handlers.push(callback)
    return
