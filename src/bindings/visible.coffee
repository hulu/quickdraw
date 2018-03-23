# Quickdraw Handler - Visiblity modifier
# 
# Registration Name: visible
# 
# Description:
#   Provides the ability to show and hide a DOM element by modifying its
#   css 'display' property to be 'none' for hide and '' for show. For
#   more fine grained control over the css property 'display' use the
#   style handler.
#   
#   You should not use this handler and the style handler with a 'display'
#   attribute modifier at the same time as there are no guarantees as
#   to which handler will take precedence. In most cases this handler
#   will be enough.
#   
# Handles Child Node Bindings: No
# 
# Possible Binding Data:
#   [Boolean]   A basic boolean or an observable that unwraps to a boolean.

qd.registerBindingHandler('visible', {
    update : (bindingData, node) ->
        # if bindingData is true, let node determine display type
        # otherwise hide it
        node.setStyle('display', if qd.unwrapObservable(bindingData) then "" else "none")

        # No reason to stop after this
        return true
})
