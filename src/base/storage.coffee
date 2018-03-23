# Utility functions for handling storage on nodes
qdInternal.storage = {
    # Stores a quickdraw associated value on the node as an internal
    # storage value
    # @param [VirtualDomNode/DomNode] node a node to store the value on
    # @param [String] name the name of the value to store
    # @param [Object] value the value to store on the node
    # 
    # @note this method should not be used outside of the core of quickdraw
    # @note virtual nodes will be correctly unwrapped
    setInternalValue : (node, name, value) ->
        @setValue(qdInternal.dom.unwrap(node), name, value, '_')
        return

    # Returns a value from a node that is stored as an internal value
    # @param [VirtualDomNode/DomNode] node a node to get the value from
    # @param [String] name the name of the value to get
    # 
    # @note this method should not be used outside of the core of quickdraw
    # @note virtual nodes will be correctly unwrapped
    getInternalValue : (node, name) ->
        return @getValue(qdInternal.dom.unwrap(node), name, '_')

    # Stores a value related to the node for a handler
    # @param [DomObject] node the node related to the value to store
    # @param [String] name the name of the value to store
    # @param [Object] value the value to store
    # @param [String] namespace the name of the storage area to group be
    #                             automagically set to your handlers name by default
    #                             
    # @note it is extremely rare that you would want to specify a non default
    #       value for the 4th parameter, but if you want to share storage
    #       between handlers that would be one easy way to do it
    setValue : (node, name, value, namespace = qdInternal.state.current.handler) ->
        storageKey = qd.getConfig('nodeDataKey')
        node[storageKey] ?= {}
        node[storageKey][namespace] ?= {}
        node[storageKey][namespace][name] = value
        return

    # Retrieves a value related to the given node for a handler
    # @param [DomObject] node the node related to the value to retrieve
    # @param [String] name the name of the value to retrieve
    # @return [Object] the originally stored object, null if there is none
    # @param [String] namespace the name of the storage area to group by
    #                             automagically set to your handlers name by default
    # 
    # @note it is extremely rare that you would want to specify a non default
    #       value for the 4th parameter, but if you want to share storage
    #       between handlers that would be one easy way to do it
    getValue : (node, name, namespace = qdInternal.state.current.handler) ->
        return node[qd.getConfig('nodeDataKey')]?[namespace]?[name] ? null

    # Removes all handler stored values on the given node
    # @param [DomObject] node the node that we want to clear all the values off of
    # @note virtual dom objects will be correctly unwrapped
    clearValues : (node) ->
        storageKey = qd.getConfig('nodeDataKey')
        return unless node[storageKey]?
        delete node[storageKey]
        # ensure we dont return the deleted data
        return
}
