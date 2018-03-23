describe("Quickdraw.Internal.Templates", ->
    generateFakeNodes = (count) ->
        return (sandbox.document.createElement('div') for i in [0...count])

    virtualizeNodes = (nodes) ->
        return (sandbox.qd._.dom.virtualize(node) for node in nodes)

    unvirtualizeNodes = (nodes) ->
        return (sandbox.qd._.dom.unwrap(node) for node in nodes)

    getHTML = (nodes) ->
        html = ""
        for node in nodes
            html += node.outerHTML

        return html

    getInternalFromAlias = (alias) ->
        return sandbox.qd._.state.templates.aliases[alias]

    getInternalFromHtml = (html) ->
        return sandbox.qd._.state.templates.html[html]

    getStoredNodes = (name) ->
        return sandbox.qd._.state.templates.nodes[name]

    describe("exists(name)", ->
        it("exists works for internal name", ->
            templateNodes = generateFakeNodes(5)
            templateName = sandbox.qd._.templates.register(templateNodes)

            assert.isTrue(sandbox.qd._.templates.exists(templateName), "Template should exist after registration")
        )

        it("exists works for alias name", ->
            templateNodes = generateFakeNodes(5)
            templateName = "myspecialname"
            sandbox.qd._.templates.register(templateNodes, templateName)
            assert.isTrue(sandbox.qd._.templates.exists(templateName), "Template should exist after registration")
        )
    )

    describe("get(name, doc)", ->
        beforeEach(->
            sandbox.templateNodes = generateFakeNodes(5)
            for node in sandbox.templateNodes
                node.textContent = Math.random()
            sandbox.templateName = sandbox.qd._.templates.register(sandbox.templateNodes)
        )

        it("requesting a non-existant template errors", ->
            errorSpy = sandbox.qd._.errors.throw = sinon.spy()
            sandbox.qd._.templates.get("doesntexist")

            assert.isTrue(errorSpy.calledOnce, "Should have called error spy")
        )

        it("should be given back virtualized nodes", ->
            nodeSet = sandbox.qd._.templates.get(sandbox.templateName)
            for node, i in nodeSet
                assert.instanceOf(node, sandbox.qd._.dom.VirtualDomNode, "Node at position #{i} is not a virtual node")
        )

        it("requesting template from get returns nodes with same html but not the same nodes", ->
            nodeSet = sandbox.qd._.templates.get(sandbox.templateName)
            originalHTML = getHTML(sandbox.templateNodes)
            copyHTML = getHTML(unvirtualizeNodes(nodeSet))
            assert.equal(nodeSet.length, sandbox.templateNodes.length, "Should have same number of nodes")
            assert.equal(copyHTML, originalHTML, "Should generate the same html")
            for node, i in sandbox.templateNodes
                assert.notEqual(nodeSet[i].getRawNode(), node, "Should not have the same node at position #{i}")
        )

        it("requesting uncached template with no document simply clones main template", ->
            for node in sandbox.templateNodes
                sinon.spy(node, "cloneNode")

            nodeSet = sandbox.qd._.templates.get(sandbox.templateName)
            for node, i in sandbox.templateNodes
                assert.isTrue(node.cloneNode.calledWith(true), "Should have recursively cloned node #{i}")
        )

        it("requesting uncached template with document imports main template", ->
            fakeDocument = {
                importNode : sinon.spy((node, deep) -> 
                    node._ownerDocument = fakeDocument
                    return node
                )
                adoptNode : sinon.spy((node) -> return node)
            }
            nodeSet = sandbox.qd._.templates.get(sandbox.templateName, fakeDocument)
            assert.equal(fakeDocument.importNode.callCount, nodeSet.length, "Should have been called for every node")
            assert.equal(fakeDocument.adoptNode.callCount, 0, "Should not have called adopt since they were created with new document")
            for node, i in unvirtualizeNodes(nodeSet)
                assert.deepEqual(fakeDocument.importNode.getCall(i).args, [node, true], "Should have been told to recursively import node #{i}")
        )

        it("requesting cached template with same document as original does no extra adoption", ->
            nodeSet = sandbox.qd._.templates.get(sandbox.templateName, sandbox.document)
            sandbox.qd._.templates.return(sandbox.templateName, nodeSet)
            adoptSpy = sandbox.document.adoptNode = sinon.spy()
            nodeSet2 = sandbox.qd._.templates.get(sandbox.templateName, sandbox.document)
            assert.isFalse(adoptSpy.called, "Should not have adopted any nodes")
            assert.deepEqual(nodeSet2, nodeSet, "Should have returned the same nodes from before")
        )

        it("requesting cached template with a new document causes adoption of each node", ->
            nodeSet = sandbox.qd._.templates.get(sandbox.templateName, sandbox.document)
            sandbox.qd._.templates.return(sandbox.templateName, nodeSet)
            adoptSpy = sinon.spy((node) -> return node)
            sandbox.qd._.templates.get(sandbox.templateName, {
                adoptNode : adoptSpy
            })
            assert.equal(adoptSpy.callCount, nodeSet.length, "Should have adopted each node")
        )
    )

    describe("return(name, nodes)", ->
        it("throws error if returning missing template", ->
            errorSpy = sandbox.qd._.errors.throw = sinon.spy()
            sandbox.qd._.templates.return("fakeNodes", [])

            assert.isTrue(errorSpy.calledOnce, "Should have thrown an error")
        )

        it("all nodes given are unwrapped", ->
            templateName = sandbox.qd._.templates.register(generateFakeNodes(1))
            nodeSet = sandbox.qd._.templates.get(templateName)
            unwrapSpy = sinon.spy(sandbox.qd._.dom, "unwrap")
            sandbox.qd._.templates.return(templateName, nodeSet)
            for node, i in nodeSet
                assert.isTrue(unwrapSpy.calledWith(node), "Should have unwrapped node at position #{i}")
        )
    )

    describe("register(nodes, name)", ->
        it("registered templates are stored correctly", ->
            templateNodes = generateFakeNodes(5)
            templateHTML = getHTML(templateNodes)

            templateName = sandbox.qd._.templates.register(templateNodes)

            assert.equal(getInternalFromHtml(templateHTML), templateName, "Template html maps to the name")
            nodes = getStoredNodes(templateName)
            assert.isDefined(nodes, "Template nodes should be stored")
            for node, i in nodes
                assert.equal(node, templateNodes[i], "Node #{i} should match original array")
        )

        it("registering with the same name twice produces an error", ->
            errorSpy = sandbox.qd._.errors.throw = sinon.spy()
            templateNodes = generateFakeNodes(5)

            sandbox.qd._.templates.register(templateNodes, "fakeName")
            sandbox.qd._.templates.register([], "fakeName")

            assert.isTrue(errorSpy.calledOnce, "Should have thrown an error for registering with the same name twice")
        )

        it("registering with a name stores with the name", ->
            templateNodes = generateFakeNodes(1)
            templateHTML = getHTML(templateNodes)
            templateName = "aTemplate"
            result = sandbox.qd._.templates.register(templateNodes, templateName)

            assert.equal(result, templateName, "Should return the template name that was given")

            internalName = getInternalFromAlias(templateName)
            assert.isDefined(internalName, "Should have used given name as an alias")

            internalHtmlName = getInternalFromHtml(templateHTML)
            assert.isDefined(internalHtmlName, "Should have html stored")
            assert.equal(internalHtmlName, internalName, "Stored html should reference internal name")
        )

        it("registering without a node returns the internal name", ->
            templateNodes = generateFakeNodes(1)
            templateHTML = getHTML(templateNodes)
            result = sandbox.qd._.templates.register(templateNodes)

            assert.isUndefined(getInternalFromAlias(result), "Result should be internal name, not an alias")
            assert.isDefined(getStoredNodes(result), "Should have nodes linked with result name")
            assert.equal(getInternalFromHtml(templateHTML), result, "Template html should link to given internal name")
        )

        it("templates that produce the same html are considered the same template internally", ->
            templateNodes = generateFakeNodes(3)

            firstName = sandbox.qd._.templates.register(templateNodes, "first")
            secondName = sandbox.qd._.templates.register(templateNodes, "second")

            assert.notEqual(firstName, secondName, "Templates should have separate names")
            firstAlias = getInternalFromAlias(firstName)
            secondAlias = getInternalFromAlias(secondName)
            assert.isDefined(firstAlias, "Should have alias for first name")
            assert.isDefined(secondAlias, "Should have alias for second name")
            assert.equal(firstAlias, secondAlias, "Both aliases should point to the same internal name")
        )

        it("registering virtualized nodes stores raw ones", ->
            templateNodes = generateFakeNodes(4)
            virtualNodes = virtualizeNodes(templateNodes)

            unwrapSpy = sinon.spy(sandbox.qd._.dom, "unwrap")

            virtualName = sandbox.qd._.templates.register(virtualNodes)
            for virtualNode, index in virtualNodes
                assert.isTrue(unwrapSpy.calledWith(virtualNode), "Should unwrap node at index #{index}")

            realName = sandbox.qd._.templates.register(templateNodes)
            assert.equal(virtualName, realName, "Registering virtual and real nodes for same html should have same internal name")
        )

        it("Any quickdraw data stored on nodes is cleared when registered", ->
            templateNodes = generateFakeNodes(1)
            sandbox.qd._.storage.setInternalValue(templateNodes[0], "test", true)
            storageSpy = sinon.spy(sandbox.qd._.storage, "clearValues")

            sandbox.qd._.templates.register(templateNodes)

            assert.isTrue(storageSpy.calledWith(templateNodes[0]), "Should have cleared data on template node")
            assert.isNull(sandbox.qd._.storage.getInternalValue(templateNodes[0], "test"), "Should have erased stored values")
        )
    )

    describe("unregister(name)", ->
        it("calling unregister with an alias deletes the alias", ->
            templateName = "fakeName"
            sandbox.qd._.templates.register(generateFakeNodes(1), templateName)
            assert.isDefined(sandbox.qd._.state.templates.aliases[templateName], "Should have alias defined")
            sandbox.qd._.templates.unregister(templateName)
            assert.isUndefined(sandbox.qd._.state.templates.aliases[templateName], "Should no longer have alias defined")
        )
    )

    describe("clearCache()", ->
        it("after clear nodes must be regenerated on request", ->
            templateName = sandbox.qd._.templates.register(generateFakeNodes(1))
            nodeSet = sandbox.qd._.templates.get(templateName)
            sandbox.qd._.templates.return(templateName, nodeSet)
            sandbox.qd._.templates.clearCache()
            nodeSet2 = unvirtualizeNodes(sandbox.qd._.templates.get(templateName))

            for node in unvirtualizeNodes(nodeSet)
                assert.isFalse(node in nodeSet2, "Should not have node returned from cache")
        )
    )
)

describe("Quickdraw.External.Templates", ->
    describe("registerTemplate(name, templateNodes)", ->
        it("registration should pass through to internal method", ->
            registerSpy = sandbox.qd._.templates.register = sinon.spy()
            name = "name"
            nodes = []
            sandbox.qd.registerTemplate(name, nodes)

            assert.isTrue(registerSpy.calledWith(nodes, name), "Should have called register spy with given data")
        )

        it("throws an error for a non-array second parameter", ->
            errorSpy = sandbox.qd._.errors.throw = sinon.spy()

            sandbox.qd.registerTemplate("")
            assert.isTrue(errorSpy.called, "Should have called error for undefined parameter")
            errorSpy.reset()

            sandbox.qd.registerTemplate("", {})
            assert.isTrue(errorSpy.called, "Should have called error for object parameter")
            errorSpy.reset()

            sandbox.qd.registerTemplate("", 1)
            assert.isTrue(errorSpy.called, "Should have called error for primative parameter")
            errorSpy.reset()

            sandbox.qd.registerTemplate("", null)
            assert.isTrue(errorSpy.called, "Should have called error for null parameter")
        )
    )
)
