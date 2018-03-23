# Quickdraw Handler - Text content modifier
# 
# Registration Name: text
# 
# Description:
#   Sets the text content of the node associated with the binding handler
#   
# Handles Child Node Bindings: No
# 
# Possible Binding Data:
#   [String]    A string of content that should be set as the text content
#               of the associated DOM node. If the content is an observable it
#               will be unwrapped and registered for updates

qd.registerBindingHandler('text', {
    update : (bindingData, node) ->
        # If the given binding data is callable, unpack its value
        dataToSet = qd.unwrapObservable(bindingData)

        # Set the text of the node to the given bindingData
        node.setProperty('textContent', dataToSet)

        # Allowed to continue beyond this node
        return true
})
