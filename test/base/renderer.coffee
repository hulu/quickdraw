describe("Quickdraw.Internal.Renderer", ->
    describe("enqueue(virtualNode)", ->
        it("errors on invalid data", ->
            errorSpy = sandbox.qd._.errors.throw = sinon.spy()
            sandbox.qd._.renderer.enqueue()

            assert.isTrue(errorSpy.called, "Should have thrown an error")
            errorSpy.reset()

            node = sandbox.document.createElement('div')
            sandbox.qd._.renderer.enqueue(node)
            assert.isTrue(errorSpy.called, "Should have thrown an error on a regular dom node")
        )

        it("virtual node added to queue", ->
            node = sandbox.document.createElement('div')
            virtualNode = sandbox.qd._.dom.virtualize(node)

            sandbox.qd._.renderer.enqueue(virtualNode)
            assert.equal(sandbox.qd._.state.render.queue[0], virtualNode, "Virtual node should be stored in render queue")
        )

        it("virtual nodes are added to queue in order enqueued", ->
            node = sandbox.document.createElement('div')
            node2 = sandbox.document.createElement('div')

            virtualNode = sandbox.qd._.dom.virtualize(node)
            virtualNode2 = sandbox.qd._.dom.virtualize(node2)

            assert.isTrue(virtualNode.getUniqueId() < virtualNode2.getUniqueId(), "Unique ids are ordered")

            sandbox.qd._.renderer.enqueue(virtualNode2)
            sandbox.qd._.renderer.enqueue(virtualNode)
            assert.equal(sandbox.qd._.state.render.queue[0], virtualNode2, "Should enqueue nodes in order given but first node is not first")
            assert.equal(sandbox.qd._.state.render.queue[1], virtualNode, "Should enqueue nodes in order given but second node is first")

            genPatch = sinon.stub(virtualNode, 'generatePatch')
            genPatch2 = sinon.stub(virtualNode2, 'generatePatch', ->
                assert.isFalse(genPatch.called, "Should not have called generate patch on node 1 yet")
            )

            emitPatch = sinon.stub(virtualNode, 'emit')
            emitPatch2 = sinon.stub(virtualNode2, 'emit', ->
                assert.isFalse(emitPatch.called, "Should not have called emit on node 1 yet")
            )

            sandbox.qd._.renderer.render()
        )
    )

    describe("render()", ->
        fakeVirtualNode = (shouldHavePatch = false) ->
            patch = if shouldHavePatch then {} else null

            return {
                patch : patch
                generatePatch : sinon.spy(-> return patch)
                emit : sinon.spy()
            }

        it("gets patches for every node", ->
            nodes = []
            renderCount = 0
            for i in [0...10]
                if i % 2 is 0
                    renderCount++
                node = fakeVirtualNode(i % 2 is 0)
                nodes.push(node)
                sandbox.qd._.state.render.queue[i] = node

            renderSpy = sandbox.qd._.renderer.renderPatch = sinon.spy()

            sandbox.qd._.renderer.render()

            for node in nodes
                assert.isTrue(node.generatePatch.called, "Should have called generate patch on node")
                assert.isTrue(node.emit.calledWith('render', null, false), "Should have emitted a synchronous render event")
                if node.patch?
                    assert.isTrue(renderSpy.calledWith(node.patch), "Should have called render for nodes patch")

            assert.equal(renderSpy.callCount, renderCount, "Should have rendered all nodes with patches")
        )
    )

    describe("renderPatch(patch)", ->
        it("sets all properties from patch", ->
            properties = {
                first : 'yes'
                second : true
                third : null
            }
            patch = {
                node : {}
                properties : properties
                attributes : {}
                styles : {}
                children : []
            }

            sandbox.qd._.renderer.renderPatch(patch)
            for property, value of properties
                assert.equal(value, patch.node[property], "Should have set property '#{property}' of node to '#{value}'")

            return
        )

        it("sets all attributes from patch", ->
            attributes = {
                first : 'thing'
                second : null
                third : true
                fourth : false
            }
            patch = {
                node : {
                    setAttribute : sinon.spy()
                    removeAttribute : sinon.spy()
                }
                properties : {}
                attributes : attributes
                styles : {}
                children : []
            }

            sandbox.qd._.renderer.renderPatch(patch)
            for attribute, value of attributes
                if value is null
                    assert.isTrue(patch.node.removeAttribute.calledWith(attribute), "Should have removed attribute '#{attribute}'")
                else
                    assert.isTrue(patch.node.setAttribute.calledWith(attribute, value), "Should have set attribute '#{attribute}' to value '#{value}'")

            return
        )

        it("sets all styles from patch", ->
            styles = {
                first : 'thing'
                second : true
            }
            patch = {
                node : {
                    style : {}
                }
                properties : {}
                attributes : {}
                styles : styles
                children : []
            }

            sandbox.qd._.renderer.renderPatch(patch)
            assert.deepEqual(patch.node.style, styles, "Should have set all the styles on the node")
        )

        it("apply children patches properly", ->
            parent = {
                removeChild: sinon.spy()
                insertBefore: sinon.spy()
            }

            children = [
                {
                    type : "remove"
                    value : {
                        parentNode : parent
                    }
                }
                {
                    type : "insert"
                    value : {}
                    leads : {}
                }
                {
                    type : "insert"
                    value : {}
                    follows : {
                        nextSibling : {}
                    }
                }
                {
                    type : "insert"
                    value : {}
                }
            ]
            patch = {
                node : parent
                properties : {}
                attributes : {}
                styles : {}
                children : children
            }

            sandbox.qd._.renderer.renderPatch(patch)
            # check first ndoe is removed
            firstChild = children[0]
            assert.isTrue(firstChild.value.parentNode.removeChild.calledWith(firstChild.value), "Should have removed a child with a remove action")

            secondChild = children[1]
            assert.isTrue(patch.node.insertBefore.calledWith(secondChild.value, secondChild.leads), "Should insert with lead references if there is one")

            thirdChild = children[2]
            assert.isTrue(patch.node.insertBefore.calledWith(thirdChild.value, thirdChild.follows.nextSibling), "Should insert with sibling of node that is followed")

            fourthChild = children[3]
            assert.isTrue(patch.node.insertBefore.calledWith(fourthChild.value, null), "No leading or following causes insertion at the end")
        )
    )
)
