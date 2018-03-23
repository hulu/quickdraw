# Quickdraw Handler - Foreach Handler
#
# Registration Name: foreach
#
# Description:
#   Given an array of similar models, this handler will duplicate the child nodes
#   of the DOM element associated with this handler and bind each model one by one
#   to them. The context in which each child is bound is a 'child' context of the
#   current node's binding context. To access the foreach node's context you can
#   use the $parent attribute on the new context. In addition you can find out the
#   numeric value of the child with the special $index value that will be added
#   to the child context by this handler.
#
#   In the case of an observable array the dependencies will be registered for updates
#   and in the event of an update only the modified elements in the array will
#   be modified by the foreach adapter. Any elements that have remain unchanged
#   will not be recreated by the handler.
#
# Handles Child Node Bindings: Yes
#
# Possible Binding Data:
#   [Array]     A javascript array or quickdraw observable array that contains a
#               set of models. Each model will be bound, in the order specified
#               to clones of the HTML specified within the node associated with
#               the foreach handler
#
# @note All caching for the foreach handler is stored on the node that contains
# the foreach binding attribute. Thus if that node is destroyed the cache will
# be appropriately cleaned up as well.
qd.registerBindingHandler('foreach', {
    initialize : (bindingData, node) ->
        # register the template with the templating system
        children = node.getChildren()

        # If the children already come from a template, return them to that pool
        # Otherwise, create a template from them.
        templateName = children[0]?.getTemplateName()
        if templateName?
            @templates.return(templateName, children)
        else
            templateName = @templates.register(children)

        # set the template name so we can reference it later
        node.setValue('childTemplate', templateName)

        # clear out the children to empty this node
        node.clearChildren()

        return

    update : (bindingData, node, bindingContext) ->
        # grab a reference to the document - do not cache globally, there could be multiple
        doc = node.getProperty('ownerDocument') || document
        templateName = node.getValue('childTemplate')

        # unwrap the binding data
        rawBindingData = qd.unwrapObservable(bindingData)

        # check if we were given a configuration object
        unless rawBindingData instanceof Array
            useTemplatesFromModels = rawBindingData.templatesFromModels
            rawBindingData = qd.unwrapObservable(rawBindingData.data)

        useTemplatesFromModels ?= false

        # create an array to store the binding pieces in
        pieces = {}

        # grab the current children
        currentChildren = node.getChildren()
        groupStartIndex = 0
        while groupStartIndex < currentChildren.length
            child = currentChildren[groupStartIndex]
            index = child.getValue('index')
            # we only care about a node if it has an index, otherwise we didnt add it
            if index?
                # figure out all the nodes that are in this group
                nodeGroup = []
                curPos = groupStartIndex
                while curPos < currentChildren.length and currentChildren[curPos].getValue('index') is index
                    nodeGroup.push(currentChildren[curPos++])

                # get the model bound to these children, it will be the same among all
                model = child.getValue('model')
                modelTemplate = nodeGroup[0].getTemplateName()

                # check if the model is in the new binding data
                newIndex = rawBindingData.indexOf(model)
                if newIndex isnt -1
                    # model was reused, save its information off to reuse it
                    pieces[newIndex] = {
                        model         : model
                        indexChanged  : newIndex isnt index
                    }

                    # grab the template from the model if possible
                    declaredTemplate = qd.unwrapObservable(rawBindingData[newIndex].template)

                    # convert to internal name, all names must be registered at this point
                    declaredTemplate = @templates.resolve(declaredTemplate)

                    # check if we want to return or reuse the template nodes
                    if not useTemplatesFromModels or modelTemplate is declaredTemplate
                        # the template is the same, reuse the nodes
                        pieces[newIndex].nodes = nodeGroup

                # return the old nodes if they were not stored off
                unless pieces[newIndex]?.nodes?
                    # this model was not used, cleanup and remove nodes
                    for leftover in nodeGroup
                        # unbind the element from any dependencies
                        qd.unbindModel(leftover)

                    # return the template to the pool
                    @templates.return(modelTemplate, nodeGroup)

                # remove node from observable dependency if it was added
                if newIndex is -1 and qd.isObservable(model.template)
                    @observables.removeDependency.call(model.template, node)

                # increment groupStartIndex by the number of nodes processed
                groupStartIndex += nodeGroup.length
            else
                # increment groupStartIndex by one to move along the array
                groupStartIndex++

        newChildren = []
        # compute the new children
        for model, i in rawBindingData
            # determine the name of the template for this model data
            modelTemplate = templateName
            if useTemplatesFromModels
                unless model.template?
                    @errors.throw(new QuickdrawError("Foreach told to use template from model but model does not specify one"))
                modelTemplate = qd.unwrapObservable(model.template)
                # if model.template is an observable we manually register the foreach as a dependency
                if qd.isObservable(model.template)
                    @observables.addDependency.call(model.template, @models.get(node), node, 'foreach')

            # get the data for this piece
            nodes = pieces[i]?.nodes ? @templates.get(modelTemplate, doc)
            indexChanged = pieces[i]?.indexChanged ? true
            nodesReused = pieces[i]?.nodes?

            # go over the children and correctly update their state
            for child in nodes
                child.setValue('index', i)
                child.setValue('model', model)

                # add the child to the new child order
                newChildren.push(child)

                # if nodetype 1 we actually want to bind the children
                if child.getProperty('nodeType') is 1
                    if nodesReused and indexChanged
                        # if these are old nodes and the index has changed update the observable
                        context = child.getValue('context')
                        context.$index(i)
                    else if not nodesReused
                        # otherwise we have not reused nodes, we need to bind everything
                        nextModel = @models.create(model)
                        childContext = bindingContext.$extend(nextModel)
                        childContext.$index = qd.observable(i)
                        @binding.bindModel(nextModel, child, childContext)
                        child.setValue('context', childContext)

        # update the nodes children
        node.setChildren(newChildren)

        # cleanup references
        rawBindingData = null
        pieces = null
        nodeGroup = null
        child = null
        node = null
        leftover = null

        # Should not continue binding any further
        return false

    cleanup : (node) ->
        templateName = node.getValue('childTemplate')
        children = node.getChildren()
        groupStartIndex = 0
        while groupStartIndex < children.length
            child = children[groupStartIndex]
            index = child.getValue('index')

            if index?
                # nodes with indicies should be grouped back into their templates and returned
                nodeGroup = []
                curPos = groupStartIndex
                while curPos < children.length and children[curPos].getValue('index') is index
                    nodeGroup.push(children[curPos++])

                # store the group template name before unbinding
                groupTemplate = child.getTemplateName() ? templateName

                # unbind all the nodes in the group
                for dispose in nodeGroup
                    qd.unbindModel(dispose)

                # return template to the cache
                @templates.return(groupTemplate, nodeGroup)

                # increment groupStartIndex
                groupStartIndex += nodeGroup.length

            else
                # nodes without indicies can be left alone, but we need to increment
                groupStartIndex++


        # get a copy of the original children and set them to be the children of this node
        originalChildren = @templates.get(templateName, node.getProperty('ownerDocument'))
        node.setChildren(originalChildren)

        # free all child references
        children = null
        child = null
        nodeGroup = null

        # prevent leak of nodes
        return

}, ["template"])
