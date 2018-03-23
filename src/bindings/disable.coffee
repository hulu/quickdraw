# Quickdraw Handler - Disable Modifier
# 
# Registartion Name: disable
# 
# Description:
#   Dynamically disables a DOM element based on the given
#   binding data. If the binding data is an observable this handler
#   will update when the observable's value changes
#
# Handles Child Node Bindings: No
# 
# Possible Binding Data:
#  [Boolean]    A simple boolean or observable that unwraps to a boolean
#               that is applied to the disabled attribute of the associated
#               DOM element

qd.registerBindingHandler('disable', {
    update : (bindingData, node) ->
        # If the given binding data is callable, unpack its value
        shouldDisable = qd.unwrapObservable(bindingData)

        # Disable if told to
        node.setProperty('disabled', if shouldDisable then true else false)

        # Allow recursion
        return true
})
