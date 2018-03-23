# Quickdraw Handler - HTML content modifier
# 
# Registration Name: html
# 
# Description:
#   Sets the html content of the node associated with the binding
#   handler. If the node has the attribute 'qdstriphtml' set on it
#   then the data will be stripped of all HTML tags before being
#   set on the DOM node.
#   
# Handles Child Node Bindings: No
#
# Possible Binding Data:
#   [String]    A string of content that should be set as the HTML
#               content of the associated DOM node. If the content
#               is an observable it will be unwrapped and registered
#               for updates

qd.registerBindingHandler('html', {
    update : (bindingData, node) ->
        # If the given binding data is callable, unpack its value
        dataToSet = qd.unwrapObservable(bindingData)

        # Set the html of the node to the given bindingData
        node.setProperty('innerHTML', dataToSet)

        # allow binding below this element
        return true
})
