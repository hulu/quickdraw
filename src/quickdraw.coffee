# Quickdraw
# A Hulu Original Library
#
# A MVVM data binding framework designed for speed and efficiency on living room devices.
# This library is optimized for light and quick loads so seamless experiences can be
# created on both low and high powered devices

# All methods that anyone can freely call will be added to the qd object that has
# been exposed to the global scope this library was executed in
qd = {}

# Always leak a "window" version of quickdraw,
# if window exists
if window?
    if window.qd?
        throw new Error("Quickdraw already defined on `window` - this probably isn't what you want.
            Check your `node_modules/` directory for multiple copies of quickdrawjs.")
    else
        window['qd'] = qd
else
    if @qd?
        throw new Error("Quickdraw already defined in current scope - this probably isn't what you want.
            Check your `node_modules/` directory for multiple copies of quickdrawjs.")
    else
        @qd = qd

# Handle node, amd, and global systems
if module?
    exports = module.exports = qd
else if exports?
    exports.qd = qd
else
    if define? and define.amd
        define(-> qd)

# All methods that are for internal use only (which does include use by binding handlers)
# will be under the qdInternal namespace. Note that this namespace should never be
# used outside of quickdraw or a binding handler but is exposed as qd._ for testability
qd._ = qdInternal = {
    # setup default configuration
    config : {
        # The attribute on the dom elements to get binding strings from
        bindingAttribute : 'data-bind'

        # The maxiumum number of updates that can queue before they are automatically applied
        maxQueuedUpdates : 25

        # Whether or not updates can currently be processed
        updatesEnabled : true

        # Whether or not updates should be handled async
        updatesAsync : true

        # Whether or not nodes should be rendered when they are ready
        renderEnabled : true

        # Whether or not renders should be handled async
        renderAsync : true

        # the default amount of time to wait before applying queued updates
        defaultUpdateTimeout : 50

        # the data storage key for a dependencies view model
        baseModelKey : 'base-view-model'

        # the key to use for data storage on nodes
        nodeDataKey : '_qdData'

        # default caching size for cache pools, -1 for infinite
        defaultCacheSize : -1
    }

    # representation of the current state
    state : {
        # the pieces currently in use for reference and snapshot
        current : {
            # the model currently being bound
            model : null

            # the element currently being bound
            element : null

            # the handler currently being used in binding
            handler : null
        }

        binding : {
            # a cache of parsed binding function strings
            functions : {}

            # the binding handlers that have been registered in the system
            handlers : {}

            # the order that handlers should be evaluated in
            order : []
        }

        error : {
            # the handlers registered to handle errors that the library may encounter
            handlers : []
        }

        updates : {
            # the key to the currently schedule update timer
            key : null

            # whether or not an immediate update has been set
            immediate : false

            # dependency updates to process on next update
            queue : []
        }

        render : {
            # the key to the currently scheduled render timer
            key : null

            # an object of node ids to whether or not they are enqueued
            enqueuedNodes : {}

            # the current set of patches to apply to the dom
            queue : []
        }

        templates : {
            # the cache that stores the current set of nodes
            cache : null

            # the set of raw node templates used to make others
            nodes : {}

            # a map of aliases to template names
            aliases : {}

            # a map of raw html to the associate template names
            html : {}
        }
    }

    updateCurrentState : (updates = {}) ->
        oldValues = {}
        # update the current state object with new values
        for key, value of updates
            oldValues[key] = qdInternal.state.current[key]
            qdInternal.state.current[key] = value

        # return a memento that can restore the previous state
        return ->
            for key, value of oldValues
                qdInternal.state.current[key] = value
}

# Set a configuration variable in the library
# @note any unknown variables will be ignored
# @param [String] configName the name of the configuration value
# @param [Mixed] configValues the value to set the property to
qd.setConfig = (configName, configValue) ->
    qdInternal.config[configName] = configValue
    return

# Gets the current setting for a configuration in the library
# @param [String] configName the name of the configuration value to get
# @return [Mixed] the value associated if set, null otherwise
qd.getConfig = (configName) ->
    return qdInternal.config[configName] ? null
