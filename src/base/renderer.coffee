# methods to deal with rendering changes to the DOM tree
qdInternal.renderer = {
    enqueue : (virtualNode) ->
        if not virtualNode? or not (virtualNode instanceof qdInternal.dom.VirtualDomNode)
            return qdInternal.errors.throw(new QuickdrawError("Cannot queue a non-virtual node for render"))

        renderState = qdInternal.state.render
        unless renderState.enqueuedNodes[virtualNode.getUniqueId()]
            renderState.enqueuedNodes[virtualNode.getUniqueId()] = true
            qdInternal.state.render.queue.push(virtualNode)

        return

    schedule : ->
        if qd.getConfig('renderAsync')
            # renders should be performed async
            unless qdInternal.state.render.key?
                if window.requestAnimationFrame?
                    qdInternal.state.render.key = -1
                    window.requestAnimationFrame(qdInternal.renderer.render)
                else
                    qdInternal.state.render.key = qdInternal.async.immediate(qdInternal.renderer.render)

                # alert that a render is scheduled to happen
                qd.emit('renderScheduled', [{
                    usingAnimationFrame: window.requestAnimationFrame?
                }], false)
        else
            # renders should happen synchronously
            qdInternal.renderer.render()

    render: ->
        # clear any current render timeout
        qdInternal.async.cancel(qdInternal.state.render.key)

        # render only if rendering is enabled
        if qd.getConfig('renderEnabled')

            # alert any listeners that a render will occur
            qd.emit('renderWillOccur', null, false)

            patchesToRender = []

            # generate a set of patches to render
            for node in qdInternal.state.render.queue
                patch = node.generatePatch()
                if patch?
                    patchesToRender.push(patch)

            # render all the patches, no calculation is done here just application
            # this is done in a separate loop to try and make it as fast as possible
            for patch in patchesToRender
                qdInternal.renderer.renderPatch(patch)

            # notify render on all nodes
            for node in qdInternal.state.render.queue
                node.emit('render', null, false)

            qdInternal.state.render.queue = []
            qdInternal.state.render.enqueuedNodes = {}

            # now that the render is complete let listeners know
            qd.emit('renderHasOccurred', null, false)

        # clear timeout key
        qdInternal.state.render.key = null

        # dont expose anything
        return

    renderPatch: (patch) ->
        # get a quick node reference
        node = patch.node

        # apply all non-children pieces of the patch first
        if patch.properties?
            for key, value of patch.properties
                node[key] = value

        if patch.attributes?
            for key, value of patch.attributes
                if value is null
                    node.removeAttribute(key)
                else
                    node.setAttribute(key, value)

        if patch.styles?
            for key, value of patch.styles
                node.style[key] = value

        # quick break if there are no child changes
        return unless patch.children?

        # apply the children updates now
        for action in patch.children
            if action.type is "remove"
                parent = action.value.parentNode
                # if the node has already moved, don't remove it.
                if node is parent
                    # capture removed for some platforms to prevent leaks
                    garbage = parent.removeChild(action.value)
            else # action type is insert
                beforeReference = null
                if action.follows? or action.leads?
                    # if follows or leads has a value in the action we use that
                    # note that following something means we must use the next
                    # sibling as the insertion point for 'insertBefore'
                    beforeReference = action.leads ? action.follows.nextSibling
                else if action.hasOwnProperty('follows')
                    # otherwise if action has a defined follow key but no value
                    # it is the head of the list and should be inserted at the front
                    beforeReference = node.firstChild

                # else would be action with a leads key and no value which means
                # it is the tail node and should be appended to the end

                garbage = node.insertBefore(action.value, beforeReference)

        # patch set completely rendered
        return
}

# Calling this method will prevent any dom updates from occuring until
# enabledRending is called. Use this if you want quickdraw to stop rendering
# changes to dom but still process observable updates
qd.disableRendering = ->
    qd.setConfig('renderEnabled', false)

    # void return
    return

# This will enable quickdraw to preform dom updates again, if there have
# been any updates to variables since this was disabled they will all be
# rendered if they are still relevant.
qd.enableRendering = ->
    qd.setConfig('renderEnabled', true)

    # render the changes to the dom now
    qdInternal.renderer.render()

    # void return
    return
