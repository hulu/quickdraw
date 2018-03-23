# Quickdraw Handler - Enable Modifier
# 
# Registartion Name: enable
# 
# Description:
#   Dynamically enables a DOM element based on the given
#   binding data. If the binding data is an observable this handler
#   will update when the observable's value changes
#
# Handles Child Node Bindings: No
# 
# Possible Binding Data:
#  [Boolean]    A simple boolean or observable that unwraps to a boolean
#               that is applied to the disabled attribute of the associated
#               DOM element

qd.registerBindingHandler('enable', {
    update : (bindingData, node) ->
        # If the given binding data is callable, unpack its value
        shouldEnable = qd.unwrapObservable(bindingData)

        # Don't disable if enabled
        node.setProperty('disabled', if not shouldEnable then true else false)

        # Allow recursion
        return true
})
