# Quickdraw Handler - Binding Complete Callback
# 
# Registration Name: complete
# 
# Description:
#   Guarantees that the given callback will be called by quickdraw after
#   the node this handler is on and its children have been bound
#
# Handles Child Node Bindings: No
# 
# Possible Binding Data:
#   [Function]  a function that will be called with the DOM node for the data-bind

qd.registerBindingHandler('complete', {
    initialize : (bindingData, node, bindingContext) ->
        unless typeof bindingData is 'function'
            error = new @errors.QuickdrawError("Binding data for complete handler must be a callback function")
            error.setBindingContext(bindingContext)
            return @errors.throw(error)

        # setup async callback that will be called once main binding is complete
        @async.immediate(-> bindingData())
})
