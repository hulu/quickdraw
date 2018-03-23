# Quickdraw Handler - Event Listeners
# 
# Registration Name: event
# 
# Description:
#   Enables listening for specified events on specified nodes. Unlike normal listening
#   each DOM node does not have listeners attached and instead only singular global
#   listeners are registered for performance.
#   
#   When events are dispatched the callback supplied through the binding string is given
#   the original binding context and the original DOM event that triggered the callback.
#   
# Handles Child Node Bindings: No
# 
# Possible Binding Data:
#   [Object]     A javascript object where the keys are event names and the values
#                are callbacks that should be executed when the event occurs with
#                the corresponding DOM node as a target.
dispatchEvent = (event) ->
    # start at the event target and work our way up
    currentTarget = event.target
    eventName = event.type
    callback = null
    while currentTarget? and not callback?
        callback = @storage.getValue(currentTarget, eventName, 'event')
        unless callback?
            currentTarget = currentTarget.parentElement

    if callback?
        # we are going to propagate on our own if there is a callback.
        event.stopPropagation()

        context = @context.get(currentTarget)
        # run the callback, look for explicit truth return
        unless callback(context, event) is true
            # cancel the default event action
            event.preventDefault()

    # dont capture loop results
    return true


qd.registerBindingHandler('event', {
    initialize : (bindingData, node) ->
        # get the owning document for our global event references
        document = node.getProperty('ownerDocument')
        globalRegistry = @storage.getValue(document, 'registry') ? {}

        for own eventName, callback of bindingData
            continue unless callback?

            # ensure we have globally registered for the event on this document
            unless globalRegistry[eventName]?
                globalRegistry[eventName] = (event) => dispatchEvent.call(@, event)
                document.addEventListener(eventName, globalRegistry[eventName], true)

            # store callback on this node for event
            node.setValue(eventName, callback)

        # store the global registry on the document
        @storage.setValue(document, 'registry', globalRegistry)

        # events should always have access to the binding context but that wont
        # be set if the element is just a simple element, so we do it manually
        # just in case there is no dynamic data
        if @state.current.model?
            @context.set(node, @state.current.model)

        # dont capture results of loops
        return
})