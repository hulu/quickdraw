# Quickdraw Handler - If
# 
# Registration Name: if
# 
# Description:
#   This binding adds/removes the child dom structure based off of the truthy value given
#   to the binding handler
#   
# Handles Child Node Binding: Yes
# 
# Possible Binding Data:
#  [Boolean]   A boolean value as to whether or not the child dom tree should be included
#              in the dom tree

qd.registerBindingHandler('if', {
    initialize : (bindingData, node) ->
        # store off the original template
        children = node.getChildren()

        # If the children already come from a template, return them to that pool
        # Otherwise, create a template from them.
        templateName = children[0]?.getTemplateName()
        if templateName?
            @templates.return(templateName, children)
        else
            templateName = @templates.register(children)

        # set the template name so we can reference it later
        node.setValue('template', templateName)
        node.setValue('hasNodes', false)

        # specify model on node so non-observable values can correctly reference the model
        @context.set(node, @state.current.model)

        # clear out the children
        node.clearChildren()

    update : (bindingData, node, bindingContext) ->
        truthValue = qd.unwrapObservable(bindingData)
        templateName = node.getValue('template')
        hasNodes = node.getValue('hasNodes')
        children = node.getChildren()

        if truthValue and not hasNodes
            # need to add the nodes back and bind
            node.setChildren(@templates.get(templateName, node.getProperty('ownerDocument')))

            # bind the children
            for child in node.getChildren()
                if child.getProperty('nodeType') is 1
                    # call bindDomTree because context and data isnt changing
                    @binding.bindModel(@models.get(node), child, bindingContext)

            node.setValue('hasNodes', true)
        else if not truthValue and hasNodes
            # need to unbind nodes and remove
            for child in children
                qd.unbindModel(child)

            # return the template
            @templates.return(templateName, children)
            node.clearChildren()
            node.setValue('hasNodes', false)

        # we took care of binding the children
        return false

    cleanup : (node) ->
        hasNodes = node.getValue('hasNodes')
        templateName = node.getValue('template')

        # add nodes back if they are missing now
        unless hasNodes
            node.setChildren(@templates.get(templateName, node.getProperty('ownerDocument')))

        # let the main unbind routine handle the unbinding
        return
}, ["template"])
