# A set of methods to manipulate dom nodes
qdInternal.dom = {
    # The current unique identifier number
    _uniqueIdentifier : 0

    # Given a dom element, assigns a unique id to it if it doesn't
    # have one already. The unique Id is then returned
    # @param [DomElement] node the element to get the unique id of
    # @return the unique node id
    uniqueId : (node) ->
        unless qdInternal.storage.getInternalValue(node, 'id')?
            qdInternal.storage.setInternalValue(node, 'id', ++@_uniqueIdentifier)

        return qdInternal.storage.getInternalValue(node, 'id')

    # Takes the given dom tree and constructs a virtualized wrapper around
    # it that can be traversed for bindings. This wrapper is used to allow
    # bindings to quickly compute the updates they wish to apply and transparently
    # apply changes to the dom nodes only after all bindings have been 
    # evaluated
    virtualize: (domNode) ->
        # if the given node is a virtual node just return it
        return domNode if (domNode instanceof qdInternal.dom.VirtualDomNode)

        # return the currently defined virtual node for an element or create one if there isnt one
        return qdInternal.storage.getInternalValue(domNode, 'virtual') ? new qdInternal.dom.VirtualDomNode(domNode)

    # @return [Node] unwraps a virtual dom node returing the raw node it modifes
    unwrap: (domNode) ->
        return null unless domNode?
        return if (domNode instanceof qdInternal.dom.VirtualDomNode) then domNode.getRawNode() else domNode

    # Allows a DOM node to be pulled across documents within the virtual dom
    # @param [Document] document the document that the node should be imported to
    # @param [DomNode] node a node that should be imported to the given document
    # @param [Boolean] deep whether or not the import should be done recursively
    importNode: (document, node, deep = true) ->
        virtualNode = qdInternal.dom.virtualize(node)
        return virtualNode.cloneNode(deep, document)

    # A virtual dom node that wraps a real dom node allowing for changes
    # to the dom node to be staged together before actually being made to
    # the dom node. The state queried on this node is always up to date with
    # the last changes made through this node, but a query on the raw node
    # may result in a stale state if the changes have not been applied by
    # the renderer yet. If you start interacting with a node through this
    # class it is recommended that you should perform all interactions with
    # the node through this class, otherwise race conditions may occur.
    #
    # Each method that can be used to mutate the state of the node is marked
    # with a '@immediate' or '@delayed' symbol. Any method that mutates the
    # raw node before returning is marked with '@immediate' while all methods
    # that defer changes until a change application are marked with '@delayed'.
    # Since the idea of this class is minimizing expensive DOM operations, the
    # tags will be accompanied with the reasoning for it as well
    VirtualDomNode : class VirtualDomNode
        uniqueIds = 0

        # Constructs a new virtual node wrapper around the given dom node
        # @param [Node] the dom node to wrap
        constructor: (domNode) ->
            @_changes = {
                properties : null
                attributes : null
                styles : null
                children : null
            }

            @_state = {
                id : uniqueIds++
                rawNode : domNode
                hasModifications : false
                templateName : null
            }

            # associate the virtual node with the raw node
            qdInternal.storage.setInternalValue(domNode, 'virtual', @)

            # add eventing to this object
            qdInternal.eventing.add(@)

            # reset the change state to default
            @_resetChangeState()

        # Disposes of the entirerty of the virtual tree starting from this node
        dispose: ->
            # dispose all children
            for child in @_changes.children ? []
                child.dispose()

            # reset changes to clear sub data properly
            @_resetChangeState()

            # delete the actual changes though
            @_changes = null

            # disassociate this virtual node
            qdInternal.storage.setInternalValue(@_state.rawNode, 'virtual', null)

            # delete the raw node reference
            delete @_state.rawNode


        getUniqueId: ->
            return @_state.id

        # @return [Node] the raw dom node this virtual node wraps
        getRawNode: ->
            return @_state.rawNode

        # Takes all the changes that have been applied to this virtual node
        # and generates a patch object that can be applied by the renderer
        # @return [Object] an object describing the patches to apply to the real
        #                  node backing this virtual one.
        #                  Null if there are no patches to apply
        generatePatch: ->
            # no patch for no modifications
            return null unless @_state.hasModifications

            # generate patch set
            patchSet = {
                node       : @_state.rawNode
                properties : @_changes.properties
                attributes : @_changes.attributes
                styles     : @_changes.styles
                children   : @_generateChildrenActions()
            }

            @_resetChangeState()

            return patchSet

        # @return [VirtualDomNode] the virtual dom node that is the parent of this
        #                          node if there is one, null otherwise
        getParentNode: ->
            # only add the parent if the state doesnt already have one defined
            # this is because we will set the parent to null to deleniate a child
            # removed from the dom tree virtually
            unless @_state.hasOwnProperty('parent')
                rawNode = @_state.rawNode
                if rawNode.parentNode? and rawNode.parentNode isnt rawNode.ownerDocument
                    @_state.parent = qdInternal.dom.virtualize(rawNode.parentNode)
                else
                    @_state.parent = null
            return @_state.parent

        # Sets the given node to be the parent node of this node
        # @param [VirtualDomNode] a virtual dom node to set as this nodes parent
        # @param [Boolean] removeFromOldParent whether or not to remove this node from the old parent
        setParentNode: (virtualNode, removeFromOldParent = true) ->
            if virtualNode? and not (virtualNode instanceof VirtualDomNode)
                qdInternal.errors.throw(new QuickdrawError("Attempting to set non-virtual node to parent of a virtual node"))

            curParent = @getParentNode()
            # do nothing if the parent hasnt changed
            return if virtualNode is curParent

            # remove this child from its current parent
            if removeFromOldParent
                curParent?.removeChild(@)

            # store the new parent
            @_state.parent = virtualNode

        # Retrieves the template associated with the node.
        getTemplateName: ->
            return @_state.templateName

        # Sets the template name for the node
        # @param [String] templateName The template this node is part of.
        setTemplateName: (templateName) ->
            @_state.templateName = templateName

        # Retrieves a value from the node's quickdraw storage with the associated string
        # @param [String] key the name of the value to retrieve
        # @param [String] namespace (optional) the namespace to use in storage if not the default
        getValue: (key, namespace) ->
            return qdInternal.storage.getValue(@_state.rawNode, key, namespace)

        # Stores a key/value pair in the node's quickdraw storage
        # @param [String] key the name of the value to store
        # @param [Mixed] value the value to store at the given key
        # @param [String] namespace (optional) the namespace to use in storage if not the default
        # @immediate this is setting a non-observed pure javascript value meaning there is
        #            no performance overhead outside of setting the actual value
        setValue: (key, value, namespace) ->
            qdInternal.storage.setValue(@_state.rawNode, key, value, namespace)
            return

        # Removes all quickdraw storage from the backing dom node
        clearValues: ->
            # clear the storage
            qdInternal.storage.clearValues(@_state.rawNode)
            
            # add this virtual node back to the dom node, only a dispose should disassociate it
            qdInternal.storage.setInternalValue(@_state.rawNode, 'virtual', @)
            
            return

        # @param [String] name the name of the property to return
        # @return [Mixed] returns a property of the backing dom node that would normally be set
        #                 directly on the node with the dot operator
        getProperty: (name) ->
            return @_changes.properties?[name] ? @_state.rawNode[name]

        # Sets a property on the backing dom node that would normally be set directly on the node
        # @param [String] name the name of the property to set
        # @param [Mixed] value the value of the property to set
        # @delayed all properties are delayed as there is a mix of observed and unobserved properties
        #          on every DOM node and the observed ones could possibly trigger an expensive reflow
        setProperty: (name, value) ->
            @_changeWillOccur()
            @_changes.properties ?= {}
            @_changes.properties[name] = value
            return

        # @param [String] name the name of the attribute to get
        # @return [Mixed] returns an attribute set on the dom node
        getAttribute: (name) ->
            if @_changes.attributes?.hasOwnProperty(name)
                return @_changes.attributes[name]
            return @_state.rawNode.getAttribute(name)

        # @param [String] name the name of the attribute to set
        # @param [Mixed] value the value to set for the attribute
        # @delayed some engines listen to all attributes set on nodes and trigger special routines
        #          when specific attributes or values are set
        setAttribute: (name, value) ->
            @_changeWillOccur()
            @_changes.attributes ?= {}
            @_changes.attributes[name] = value
            return

        # @param [String] name the name of the attribute to delete
        removeAttribute: (name) ->
            @_changeWillOccur()
            @_changes.attributes ?= {}
            @_changes.attributes[name] = null
            return

        # @param [String] name the name of the attribute to check
        hasAttribute: (name) ->
            if @_changes.attributes?.hasOwnProperty(name)
                return @_changes.attributes[name]?
            return @_state.rawNode.hasAttribute(name)

        # @param [String] name the name of a css property to read from the node
        # @return [Mixed] the value associated with the given name in the css style
        #                 object for this node
        getStyle: (name) ->
            return @_changes.styles?[name] ? @_state.rawNode.style[name]

        # @param [String] name the name of a css property to set on the node
        # @param [Mixed] value the value to assign to the css property
        # @delayed any and all css style changes have the ability to trigger reflows
        setStyle: (name, value) ->
            @_changeWillOccur()
            @_changes.styles ?= {}
            @_changes.styles[name] = value
            return

        # Adds an event listener to the dom node
        # This method acts as a passthrough to the wrapped node
        # @immediate while event triggering has an overhead, there doesn't appear to be any large
        #            negative performance implications for adding/removing listeners
        addEventListener: (args...) ->
            return @_state.rawNode.addEventListener(args...)

        # Removes an event listener from the dom node
        # This method acts as a passthrough to the wrapped node
        # @immediate while event triggering has an overhead, there doesn't appear to be any large
        #            negative performance implications for adding/removing listeners
        removeEventListener: (args...) ->
            return @_state.rawNode.removeEventListener(args...)

        # Returns all of the current children of this node that would normally be
        # present in the 'children' array of the node but updated for any changes
        # @param [Boolean] copy if true then a copy of the internal array is returned
        # @return [VirtualDomNode[]] an array of virtual dom nodes that are the children of this node
        getChildren: (copy = false) ->
            @_generateVirtualChildren()

            unless copy
                return @_changes.children

            # slice to return a copy
            return @_changes.children.slice()

        # @param [Mixed] a real or virtual node to determine if it is a child of this node
        # @return [Boolean] whether or not the given child is a child of this node
        isChild: (child) ->
            @_generateVirtualChildren()
            virtualChild = qdInternal.dom.virtualize(child)
            return (virtualChild in @_changes.children)

        # Removes the given child from the dom node and returns it
        # @param [Mixed] child the real or virtual dom node to remove from this node
        # @return [Node] the virtual child that has been removed
        # @throw [Exception] if the given child is not a child of this node
        removeChild: (child) ->
            @_generateVirtualChildren()

            # children will be modified
            @_changeWillOccur()

            virtualChild = qdInternal.dom.virtualize(child)
            index = @_changes.children.indexOf(virtualChild)
            
            # error if the given child is not a child of this node
            if index is -1
                return qdInternal.errors.throw(new QuickdrawError("Given element is not a child of this node"))

            # otherwise remove the child from the children array and return the raw node
            @_changes.children.splice(index, 1)

            # set the parent node to null but done remove from the parent again because thats us
            virtualChild.setParentNode(null, false)

            return virtualChild

        # Appends the given child to this dom node as the last child in this node
        # param [Mixed] child the child to add to this node
        appendChild: (child) ->
            @_generateVirtualChildren()

            # children will be modified
            @_changeWillOccur()

            virtualChild = qdInternal.dom.virtualize(child)
            index = @_changes.children.indexOf(virtualChild)

            # special cases for when child already a child of this node
            if index isnt -1
                # return now if the child is already at the end
                return virtualChild if index is @_changes.children.length - 1

                # otherwise remove the child from the array
                @_changes.children.splice(index, 1)

            # now insert the child at the end of the array
            @_changes.children.push(virtualChild)

            # set the virtual childs parent
            virtualChild.setParentNode(@)

            # return the newly appended virtual child
            return virtualChild

        # Inserts the given child before the reference child node
        # If the reference node is null this will act as append
        # @param [Mixed] child the child to add to this node
        # @param [Mixed] referenceNode the node to use as a reference point
        insertBefore: (child, referenceNode) ->
            @_generateVirtualChildren()

            # children will be modified
            @_changeWillOccur()

            unless referenceNode?
                # if no reference node given, treat as append
                return @appendChild(child)

            virtualChild = qdInternal.dom.virtualize(child)
            virtualReference = qdInternal.dom.virtualize(referenceNode)

            childIndex = @_changes.children.indexOf(virtualChild)
            referenceIndex = @_changes.children.indexOf(virtualReference)
            # if the reference node is not actually a child of this node error out
            if referenceIndex is -1
                return qdInternal.errors.throw(new QuickdrawError("Reference node is not a child of this node"))

            # if the child is already a child of this node do some preprocessing
            if childIndex isnt -1
                # do nothing if the child is already in the right place
                return virtualChild if childIndex + 1 is referenceIndex

                # otherwise remove the child and recompute the reference index
                @_changes.children.splice(childIndex, 1)
                referenceIndex = @_changes.children.indexOf(virtualReference)

            # insert the node before the reference node
            @_changes.children.splice(referenceIndex, 0, virtualChild)

            # set the virtual childs parent
            virtualChild.setParentNode(@)

            # return the newly inserted virtual child
            return virtualChild

        # Removes all children from this dom node
        clearChildren: ->
            @_generateVirtualChildren()

            # children will be modified
            @_changeWillOccur()

            for child in @_changes.children
                # set the parent to null, dont remove from parent since we are doing that now
                child.setParentNode(null, false)

            # erase all the children
            @_changes.children.length = 0
            return

        # Takes the given set of children and sets them to be this nodes children
        setChildren: (children) ->
            # clear out all of the children
            @clearChildren()

            # repopulate the child array with the given children
            for child in children
                virtualChild = qdInternal.dom.virtualize(child)
                virtualChild.setParentNode(@)
                @_changes.children.push(virtualChild)

            # prevent the loop capture
            return

        # Constructs a virtual clone tree that can be rendered to a full tree
        # @param [Boolean] deep whether or not the node should be recursively cloned
        # @param [Document] (optional) document the document that the cloned node should belong to
        cloneNode: (deep = true, document = @_state.rawNode.ownerDocument) ->
            # returns a clone of the virtual and any backing real nodes
            if document is @_state.rawNode.ownerDocument
                copy = @_state.rawNode.cloneNode(false)
            else
                copy = document.importNode(@_state.rawNode, false)

            virtualCopy = qdInternal.dom.virtualize(copy)

            changedProperty = false
            if @_changes.properties?
                virtualCopy._changes.properties = {}
                for property, value of @_changes.properties
                    changedProperty = true
                    virtualCopy._changes.properties[property] = value

            if @_changes.attributes?
                virtualCopy._changes.attributes = {}
                for attribute, value of @_changes.attributes
                    changedProperty = true
                    virtualCopy._changes.attributes[attribute] = value

            if @_changes.styles?
                virtualCopy._changes.styles = {}
                for style, value of @_changes.styles
                    changedProperty = true
                    virtualCopy._changes.styles[style] = value

            # since a property update must be applied, ensure enqueued for render
            if changedProperty
                virtualCopy._changeWillOccur()

            # if deep clone was requested we need to appropriately clone children
            if deep
                # generate our virtual children so we can clone
                @_generateVirtualChildren()

                # since this node and the children are clones we can attach the
                # children directly without worrying about style reflows
                for child, i in @_changes.children
                    newChild = child.cloneNode(true, document)
                    copy.appendChild(newChild.getRawNode())

                # however we need to ensure states are consistent so force the
                # virtual copy to generate its child array
                virtualCopy.getChildren()

            return virtualCopy

        _resetChangeState: ->
            # reset the modifications flag back to false
            @_state.hasModifications = false

            # delete the parent reference as we will want to take
            # the parent from the node when asked later
            delete @_state.parent

            # reset the values within changes, we differ the creation
            # of any sub-objects until they are actually used to cut
            # down on the memory churn that can occur during updates
            @_changes.properties = null
            @_changes.attributes = null
            @_changes.styles = null
            @_changes.children = null

            # dont return object
            return

        _changeWillOccur: ->
            unless @_state.hasModifications
                @_state.hasModifications = true

                # register node to be rendered
                qdInternal.renderer.enqueue(@)

            return

        _generateVirtualChildren: ->
            return if @_changes.children?

            # generate a child array of virtual children to perform operations on
            @_changes.children = []
            for child in @_state.rawNode.children
                virtualChild = qdInternal.dom.virtualize(child)
                virtualChild.setParentNode(@)
                @_changes.children.push(virtualChild)

            return

        _generateChildrenActions: ->
            # if the children were not changed, nothing to do
            return [] unless @_changes.children?

            # otherwise we need to generate a diff between the current and expected child arrays
            currentChildren = @_state.rawNode.children
            expectedChildren = new Array(@_changes.children.length)
            for child, i in @_changes.children
                expectedChildren[i] = child.getRawNode()

            actions = []
            prunedChildren = []
            for child in currentChildren
                if not (child in expectedChildren)
                    actions.push({
                        type  : "remove"
                        value : child
                    })
                else
                    prunedChildren.push(child)

            mappingArray = new Array(expectedChildren.length)
            for value, index in expectedChildren
                mappingArray[index] = {
                    leads   : expectedChildren[index + 1] ? null
                    follows : expectedChildren[index - 1] ? null
                    value   : value
                }

            actionsForward = actions
            arrayForward = prunedChildren
            actionsBackward = actions.slice()
            arrayBackward = prunedChildren.slice()

            # do the forward mapping
            for map, index in mappingArray by 1
                curIndex = arrayForward.indexOf(map.value)
                # if the time is already at the correct index just skip it
                continue if curIndex is index

                if curIndex isnt -1
                    # remove item from our logical array but dont specify an action since
                    # the dom insertion will auto remove it
                    arrayForward.splice(curIndex, 1)

                actionsForward.push({
                    type    : "insert"
                    value   : map.value
                    follows : map.follows
                })
                arrayForward.splice(index, 0, map.value)

            # do the backward mapping now, its a bit more complicated since the array size can change
            for index in [0 ... mappingArray.length]
                map = mappingArray[mappingArray.length - 1 - index]

                curIndex = arrayBackward.indexOf(map.value)
                correctIndex = Math.max(0, arrayBackward.length - 1 - index)

                # if the item is already in the correct position don't move it now
                continue if correctIndex is curIndex

                if curIndex isnt -1
                    # element exists in the array, remove it and again dont track the removal
                    arrayBackward.splice(curIndex, 1)

                if map.leads is null
                    correctIndex = arrayBackward.length
                else
                    correctIndex = arrayBackward.indexOf(map.leads)

                actionsBackward.push({
                    type   : "insert"
                    value  : map.value
                    leads  : map.leads
                })
                arrayBackward.splice(correctIndex, 0, map.value)

            # return the action set that is shorter
            return if actionsForward.length > actionsBackward.length then actionsBackward else actionsForward
}
