describe("Quickdraw.Binding.Template", ->
    it("Handler is bound to template keyword", assertModuleBound('template'))

    it("Error thrown when template not registered with quickdraw", ->
        sandbox.qd._.templates.exists = -> return false
        errorSpy = sinon.stub(sandbox.qd._.errors, 'throw')

        initialize = qdGetInitialize('template')
        initialize('fakeName', {}, {})

        assert.isTrue(errorSpy.calledOnce, "Should have called error spy since template given doesn't exist")
    )

    it("template nodes correctly set as children", ->
        fakeNodes = [{}, {}, {}]
        sandbox.qd._.templates.exists = -> return true
        sandbox.qd._.templates.get = -> return fakeNodes

        virtualNode = sandbox.qd._.dom.virtualize(sandbox.document.createElement('div'))

        initialize = qdGetInitialize('template')
        result = initialize('fakeName', virtualNode, {})

        children = virtualNode.getChildren()
        assert.isTrue(result, "Should allow binding of children")
        assert.equal(children.length, fakeNodes.length, "Should have complete template as children")
        for child, i in children
            assert.equal(child.getRawNode(), fakeNodes[i], "Node at position #{i} in template should be #{i}th child")

        # no loop captures
        return
    )

    it("on unbind template is removed", ->
        fakeNodes = [{}, {}, {}]
        sandbox.qd._.binding.unbindDomTree = ->
        sandbox.qd._.templates.exists = -> return true
        sandbox.qd._.templates.get = -> return fakeNodes
        returnSpy = sandbox.qd._.templates.return = sinon.spy()

        virtualNode = sandbox.qd._.dom.virtualize(sandbox.document.createElement('div'))

        initialize = qdGetInitialize('template')
        initialize('fakeName', virtualNode, {})

        cleanup = qdGetCleanup('template')
        cleanup(virtualNode)
        assert.equal(returnSpy.firstCall.args[0], 'fakeName', "Should have template named 'fakeName'")

        children = virtualNode.getChildren()
        assert.equal(children.length, 0, "Should have no children now")
    )
)