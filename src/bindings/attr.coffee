# Quickdraw Handler - Attribute Modifier
# 
# Registration Name: attr
# 
# Description:
#   Sets the attributes on a DOM element using the data from a binding
#   context. Data that is wrapped as an observable will be updated
#   when a change is made to the observable.
#
# Handles Child Node Bindings: No
# 
# Possible Binding Data:
#   [Object]    a javascript object where the keys are valid DOM attributes
#               and the values are the values to be assigned for those attributes.
#               Any values that are observables will be properly extracted
#               and registered for updates
qd.registerBindingHandler('attr', {
    update : (bindingData, node) ->
        # for each attribute specified, go through and add them to the node
        boundAttributes = node.getValue('attributes') ? {}
        for own attrName, value of qd.unwrapObservable(bindingData)
            newValue = qd.unwrapObservable(value)
            oldValue = node.getAttribute(attrName)
            boundAttributes[attrName] = true

            if newValue? and oldValue isnt newValue
                node.setAttribute(attrName, newValue)
            else if not newValue?
                node.removeAttribute(attrName)

        node.setValue('attributes', boundAttributes)

        # can descend past here
        return true

    cleanup : (node) ->
        for attrName, value of node.getValue('attributes')
            node.removeAttribute(attrName)
        # prevent loop captures
        return
})
