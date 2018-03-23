# Functions related to updates that need to be dealt with
qdInternal.updates = {

    # Fires the updates that have been queued in quickdraw
    run : ->
        # clear timeout but dont reset update key yet
        qdInternal.async.cancel(qdInternal.state.updates.key)

        # only perform updates if updates are enabled
        if qd.getConfig('updatesEnabled')

            # rebind all of the nodes that have been queued
            qdInternal.updates.updateNodeSet(qdInternal.state.updates.queue)

            # 'clear' the array
            qdInternal.state.updates.queue.length = 0

        # clear the timeouts after binding, this prevents any changes that happen
        # during binding from scheduling a new update to be run
        qdInternal.state.updates.key = null
        qdInternal.state.updates.immediate = false

        # dont return anything
        return

    # Updates the given set of node such that they no longer have dirty states
    # @param [DomNode[]] nodes a set of DomNodes that need to be updated
    updateNodeSet : (nodes) ->
        # alert any listeners that binding updates will occur
        qd.emit("updatesWillOccur", null, false)

        i = 0
        # use a while loop so that we rebind any additional nodes added to
        # an array via reference while our run loop is going
        while i < nodes.length
            # grab the node and increment i
            dependency = qdInternal.dom.virtualize(nodes[i++])

            # get the binding context this node should be evaluated in
            # it is created from the stored data
            bindingContext = qdInternal.context.get(dependency)

            # if there is no binding context, skip
            continue unless bindingContext?

            # update the bindings on the dom node
            qdInternal.binding.updateDomNode(dependency, bindingContext)

        # clear the template cache since updates are done
        qdInternal.templates.clearCache()

        # schedule the changes to the dom to be rendered
        qdInternal.renderer.schedule()

        # now that updates have finished let any listeners know
        qd.emit("updatesHaveOccurred", null, false)

        # prevent loop capture
        return

    # Schedules any queued updates to be fired, if an update has already
    # been schedule no new updates are schedule and the current one is left in place
    # @param [Boolean] immediately if true updates will be set to run regardless of current queue size
    #                              if false updates will be set to run when the queue max has
    #                              been reached or the default update timeout occurs, whichever is first
    schedule : (immediately = false) ->
        if qd.getConfig('updatesAsync')
            # all updates should be done async when done via schedule
            updatesState = qdInternal.state.updates
            if updatesState.queue.length >= qd.getConfig('maxQueuedUpdates') or immediately
                # only set the immediate update once
                unless updatesState.immediate
                    qdInternal.async.cancel(updatesState.key)
                    updatesState.key = qdInternal.async.immediate(qdInternal.updates.run)
                    updatesState.immediate = true
            else unless updatesState.key?
                updatesState.key = qdInternal.async.delayed(qdInternal.updates.run, qd.getConfig('defaultUpdateTimeout'))
        else
            # all updates are done synchronously, we call run directly
            qdInternal.updates.run()

        # dont return any state
        return

    enqueue : (domNode) ->
        unless domNode in qdInternal.state.updates.queue
            qdInternal.state.updates.queue.push(domNode)
        # prevent return
        return
}

# Calling this method will prevent any dom updates from occuring until
# enableUpdates is called. Use this if you want quickdraw to stop working
# during a critical path in your system
qd.disableUpdates = ->
    qd.setConfig('updatesEnabled', false)
    # cancel any impending updates to prevent cycle waste
    qdInternal.async.cancel(qdInternal.state.updates.key)
    qdInternal.state.updates.key = null

    # void return
    return

# This will enable quickdraw to perform updates again, if there have
# been any updates that have occured since updates were disabled
# they will be set to execute
# @param [Boolean] runEnqueuedSynchronously whether or not to run the current queue of updates
#                                           before returning or async after returning
qd.enableUpdates = (runEnqueuedSynchronously = false) ->
    qd.setConfig('updatesEnabled', true)
    if qdInternal.state.updates.queue.length > 0
        # always schedule update so that key/immediate are set correctly
        qdInternal.updates.schedule(true)
        if runEnqueuedSynchronously
            qdInternal.updates.run()

    # dont return result
    return
