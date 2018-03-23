# Quickdraw Handler - CSS Class Modifier
#
# Registaration Name: css
#
# Description:#
#   Sets the class names of a DOM element using the data supplied by a
#   binding context for the element. Data that is provided by an observable
#   will be updated whena  change is made to the observable.
#
#   In the event that a DOM node has an original set of classes, those classes
#   will remain unmodified by this handler. If a class needs to be dynamically
#   added and removed from the DOM element it should be specified as part of
#   the binding data for this handler. Any classes that are originally specified
#   in the DOM node CAN NOT be removed by this handler.
#
# Handles Child Node Bindings: No
#
# Possible Binding Data:
#   [Object]    A javascript obejct where the keys are valid CSS selectors
#               and the values are booleans where true signifies a class should
#               be appended to the dom element, and false signifies a class
#               should be removed.
#
#               It is also permitted for one key to be the string '_$', this
#               is an invalid CSS selector, but the value associated with it
#               will be treated as class names that should be directly appended.
#               For instance '_$' : 'one two' will append the classes 'one' and
#               'two' to the dom element. This key may also be attached to
#               an observable and classes will be appropriately added and removed

CSS_CLASS_DELIM = " "

qd.registerBindingHandler('css', {
    initialize : (bindingData, node) ->
        # store the original classes as an array
        tokenizer = new @strings.tokenizer(node.getProperty('className') ? "", CSS_CLASS_DELIM)
        node.setValue('original', tokenizer.toArray())

    update : (bindingData, node) ->
        toKeep = {}
        original = node.getValue('original')
        tokenizer = new @strings.tokenizer(node.getProperty('className'), CSS_CLASS_DELIM)
        bindingData = qd.unwrapObservable(bindingData)

        # initially state that all classes from the original set should be saved
        for value in original
            toKeep[value] = true

        if typeof bindingData is 'object'
            # Parse all currently applied classes, set their keep state to true
            # if a binding data value results in false it will be removed
            tokenizer.map((token) ->
                # only keep tokens that are class names in binding data
                # drop anything that was previously applied via _$
                if bindingData[token]?
                    toKeep[token] = true
            )

            # Go through all the classnames in binding data and flag them to keep or remove
            for own className, truth of bindingData
                truth = qd.unwrapObservable(truth)
                if className is '_$'
                    toKeep[truth] = true
                else
                    toKeep[className] = truth

        else if bindingData?
            # assume binding data is a string to append
            toKeep[bindingData] = true

        # build up class string
        classString = ""
        for aClass, keep of toKeep when keep
            classString = @strings.appendWithDelimiter(classString, aClass, CSS_CLASS_DELIM)

        # apply the new class names to the original
        node.setProperty('className', classString)

        # Allowed to continue after this
        return true

    cleanup : (node) ->
        original = node.getValue('original') ? []
        node.setProperty('className', original.join(CSS_CLASS_DELIM))

})
