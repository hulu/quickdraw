# Quickdraw Handler - Event Listeners
#
# Registration Name: event
#
# Description:
#   Enables listening for specified events on nodes. There are two forms of this
#   binding which work slightly differently:
#
#   The default form takes a map of event types to handler functions. Unlike
#   normal listening each DOM node does not have listeners attached and instead
#   only singular global listeners are registered on the document For backwards
#   compatibility reasons these handlers use the capture phase of the event
#   lifecycle and stop event propogation when events occur.
#
#   In the second form a map of event types to objects should be provided. Each
#   object should contain a `handler` key which will be invoked when the event
#   occurs. In this case the event handler is attached to individual DOM nodes
#   rather than to the parent document, and the bubbling phase is used for event
#   handling.
#
#   When events are dispatched the callback supplied through the binding string
#   is given the original binding context and the original DOM event that
#   triggered the callback.
#
# Handles Child Node Bindings: No
#
# Possible Binding Data:
#   [Object]     A javascript object where the keys are event names and the values
#                are callbacks that should be executed when the event occurs with
#                the corresponding DOM node as a target. If attaching the event
#                listener to the node itself and skipping the capture phase is
#                desired, the value of the object should instead be an object with
#                `useCapture` and `callback` keys
#
# Examples:
#   // event listener hoisted to document and capture phase is used
#   event: { click: onClick }
#
#   // event listener attached to node and bubbling phase is used
#   event: { click: { handler: onClick } }
#
#   // mixture of both strategies
#   event: { click: onClick, blur: { handler: onBlur } }

HANDLER_NAME = 'event'

dispatchEvent = (event) ->
    # start at the event target and work our way up
    currentTarget = event.target
    eventName = event.type
    callback = null
    while currentTarget? and not callback?
        callback = @storage.getValue(currentTarget, eventName, HANDLER_NAME)
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

    return true

###*
# Registers an event listener on the document which will intercept events during
# the capture phase
###
registerGlobalHandler = (node, eventName, callback) ->
    document = node.getProperty('ownerDocument')
    globalRegistry = @storage.getValue(document, 'registry') ? {}

    # ensure we have registered for the event on this document
    unless globalRegistry[eventName]?
        globalRegistry[eventName] = (event) => dispatchEvent.call(@, event)
        document.addEventListener(eventName, globalRegistry[eventName], true)

        # store callback on this node for event
        node.setValue(eventName, callback)

        # store the global registry on the document
        @storage.setValue(document, 'registry', globalRegistry)

    return

###*
# Registers an event listener on the bound DOM node which will respond to events
# during the bubble phase
###
registerLocalHandler = (node, eventName, callback) ->
    eventRegistry = @storage.getValue(node, 'registry') ? {}

    unless eventRegistry[eventName]?
        eventRegistry[eventName] = (event) => dispatchEvent.call(@, event)
        node.addEventListener(eventName, eventRegistry[eventName])
        node.setValue(eventName, callback)

        @storage.setValue(node, 'registry', eventRegistry)

    return

initialize = (bindingData, node) ->
    for own eventName, binding of bindingData
        continue unless binding?

        if typeof binding is 'function'
            handler = binding
            registerGlobalHandler.call(@, node, eventName, handler)
        else
            { handler } = binding
            registerLocalHandler.call(@, node, eventName, handler)

    # events should always have access to the binding context but that wont
    # be set if the element is just a simple element, so we do it manually
    # just in case there is no dynamic data
    if @state.current.model?
        @context.set(node, @state.current.model)

    return

cleanup = (bindingData, node) ->
    registry = @storage.getValue(node, 'registry') ? {}

    for eventName, binding of registry
        node.setValue(eventName, null)
        node.removeEventListener(eventName, binding)

qd.registerBindingHandler(HANDLER_NAME, { initialize, cleanup })
