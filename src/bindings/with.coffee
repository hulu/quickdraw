# Quickdraw Handler - With
# 
# Registration Name: with
# 
# Description:
#   Creates a new binding context where the data values in the new context
#   are values specified within the binding data. The new binding context
#   that is created is a 'child' context of the current one and it can reference
#   the current one through the $parent attribute of the context.
#   
# Handles Child Node Bindings: Yes
# 
# Possible Binding Data:
#   [Any]   Any value or observable to use as the main binding model for all
#           the child nodes of the current DOM element. In the event of an
#           observable it will be unwrapped and registered for updates.
qd.registerBindingHandler('with', {
    initialize : (bindingData, node) ->
        # store off original nodes for template
        children = node.getChildren()

        # If the children already come from a template, return them to that pool
        # Otherwise, create a template from them.
        templateName = children[0]?.getTemplateName()
        if templateName?
            @templates.return(templateName, children)
        else
            templateName = @templates.register(children)

        # set the template name so we can reference it later
        node.setValue('originalTemplate', templateName)

        # clear out the children to empty this node
        node.clearChildren()

        return

    update : (bindingData, node, bindingContext) ->
        dataToBind = qd.unwrapObservable(bindingData)
        templateName = node.getValue('originalTemplate')

        # check if they used the custom options object syntax
        if dataToBind? and dataToBind.templateFromModel?
            useTemplateFromModel = dataToBind.templateFromModel
            # ensure they provide a submodel if they use the options object syntax
            unless dataToBind.hasOwnProperty('model')
                @errors.throw(new QuickdrawError("When specifing options to 'with' you must specify a model to use for child binding"))
            # set the data to bind as the submodel given
            dataToBind = qd.unwrapObservable(dataToBind.model)

            # if they asked us to use the model's template, do so now
            if dataToBind? and useTemplateFromModel
                unless dataToBind.template?
                    @errors.throw(new QuickdrawError("You have requested 'with' to use templates from the model but have not specified one"))
                templateName = qd.unwrapObservable(dataToBind.template)

        # get current information so we can short-circuit where possible
        currentTemplate = node.getValue('template')
        templateHasChanged = templateName isnt currentTemplate
        dataHasChanged = dataToBind isnt node.getValue('model')

        # if we have something bound and either:
        # 1) there is no longer data to bind
        # 2) the template name has changed
        # we need to unbind the current nodes and return them to the cache
        if currentTemplate? and (dataHasChanged or templateHasChanged)
            children = node.getChildren()
            for child in children
                qd.unbindModel(child)

            node.setValue('model', null)

            # if the template has changed or there is no data we should clear
            # the children and reset the template information
            if not dataToBind? or templateHasChanged
                @templates.return(currentTemplate, children)
                node.setValue('template', null)
                node.clearChildren()

        # we can stop here if there is no data to bind
        # still consider us having taken care of the children binding
        return false unless dataToBind?

        if templateHasChanged
            # bring in the appropriate children for this template
            node.setChildren(@templates.get(templateName, node.getProperty('ownerDocument')))
            node.setValue('template', templateName)

        if dataHasChanged or templateHasChanged
            childBindingData = @models.create(dataToBind)
            childContext = bindingContext.$extend(childBindingData)

            for child in node.getChildren()
                if child.getProperty('nodeType') is 1
                    @binding.bindModel(childBindingData, child, childContext)

            node.setValue('model', dataToBind)

        # we took care of binding the children
        return false

    cleanup : (node) ->
        currentTemplate = node.getValue('template')
        templateName = node.getValue('originalTemplate')

        if currentTemplate?
            # unbind and return all the children
            children = node.getChildren()
            for child in children
                qd.unbindModel(child)

            @templates.return(currentTemplate, children)

        # if the original template needs to be restored do it now
        node.setChildren(@templates.get(templateName, node.getProperty('ownerDocument')))

        return

}, ["template"])
