# Functions related to the templating subsystem
qdInternal.templates = {
    _uniqueId : 0

    _generator : (name, doc) ->
        nodes = qdInternal.state.templates.nodes[name]
        newNodes = new Array(nodes.length)
        for node, index in nodes
            if doc?
                # if a document reference is given, import the node with that reference
                newNodes[index] = doc.importNode(node, true)
            else
                # otherwise simply clone the node
                newNodes[index] = node.cloneNode(true)
        return newNodes

    resolve : (name) ->
        return qdInternal.state.templates.aliases[name] ? name

    exists : (name) ->
        realName = qdInternal.state.templates.aliases[name] ? name
        return qdInternal.state.templates.nodes[realName]?

    get : (name, doc) ->
        templateState = qdInternal.state.templates
        realName = templateState.aliases[name] ? name

        unless templateState.nodes[realName]?
            return qdInternal.errors.throw(new QuickdrawError("No template defined for given name"))

        unless templateState.cache?
            # if the cache has not been defined yet, do so now
            templateState.cache = qdInternal.cache.create(qdInternal.templates._generator)

        nodes = templateState.cache.get(realName, doc)

        for i in [0...nodes.length]
            node = nodes[i]
            if doc? and node.ownerDocument isnt doc
                # we need to adopt the node before it can be used
                node = doc.adoptNode(node)

            # virtualize the dom node that we return
            nodes[i] = qdInternal.dom.virtualize(node)
            nodes[i].setTemplateName(realName)

        # return the nodes
        return nodes

    return : (name, nodes) ->
        templateState = qdInternal.state.templates
        realName = templateState.aliases[name] ? name

        unless templateState.nodes[realName]?
            return qdInternal.errors.throw(new QuickdrawError("Given name is not a valid template name"))

        # ensure the nodes are unwrapped if they are virtual
        storageNodes = new Array(nodes.length)
        for node, i in nodes
            storageNodes[i] = qdInternal.dom.unwrap(node)

        templateState.cache.put(realName, storageNodes)
        return

    register : (nodes, name) ->
        templateState = qdInternal.state.templates

        if templateState.aliases[name]?
            return qdInternal.errors.throw(new QuickdrawError("Template already defined for given name `#{name}`"))

        # Virtual nodes may already be from a template. If that's the case, they do not
        # need to be parsed into HTML again.
        if nodes[0]? and (nodes[0] instanceof qdInternal.dom.VirtualDomNode)
            templateName = nodes[0].getTemplateName()

        unless templateName?
            # generate an HTML string for the nodes given and construct a fragment
            html = ""
            cleanNodes = new Array(nodes.length)
            for node, i in nodes
                # we only want to store non-virtual elements to generate from
                node = qdInternal.dom.unwrap(node)

                # store the node in the cleaned up set
                cleanNodes[i] = node

                # completely wipe all data from the node, we dont care about anything including virtual changes
                qdInternal.storage.clearValues(node)

                # append the outer html of the node
                html += node.outerHTML

            unless templateState.html[html]?
                templateName = qdInternal.templates._uniqueId++
                templateState.html[html] = templateName
                templateState.nodes[templateName] = cleanNodes
            else
                templateName = templateState.html[html]

        # add the given name as an alias to this info set
        if name?
            templateState.aliases[name] = templateName

        # return the given name or a generated name if no name given
        return name ? templateName

    unregister : (name) ->
        delete qdInternal.state.templates.aliases[name]
        return

    clearCache : ->
        qdInternal.state.templates.cache?.clear()
        return
}


qd.registerTemplate = (name, templateNodes) ->
    unless templateNodes instanceof Array
        return qdInternal.errors.throw(new QuickdrawError("Nodes for template must be given as an array"))

    return qdInternal.templates.register(templateNodes, name)
