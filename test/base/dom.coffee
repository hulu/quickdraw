describe("Quickdraw.Internal.Dom", ->
    describe("uniqueNodeId(node):", ->
        it("node without id is given a new one", ->
            dom = sandbox.document.createElement("div")
            sandbox.qd._.dom.uniqueId(dom)

            assert.isNotNull(dom._qdData._.id, "Element now has a unique id")
        )

        it("node with id is not reassigned", ->
            dom = sandbox.document.createElement("div")
            dom.setAttribute("data-unique", 23)

            sandbox.qd._.dom.uniqueId(dom)
            assert.equal(dom.getAttribute("data-unique"), 23, "Element has original id still")
        )
    )

    describe("virtualize(domNode)", ->
        it("a non virtualized node is correctly virtualized", ->
            domNode = {}
            virtualNode = sandbox.qd._.dom.virtualize(domNode)

            assert.isTrue(virtualNode instanceof sandbox.qd._.dom.VirtualDomNode, "Should create an instance of the virtual dom node class")
            assert.equal(virtualNode.getRawNode(), domNode, "Should wrap the given dom node")
        )

        it("a virtualized node returns the previous instance", ->
            domNode = {}
            fakeVirtual = {}
            sandbox.qd._.storage.setInternalValue(domNode, 'virtual', fakeVirtual)

            virtualNode = sandbox.qd._.dom.virtualize(domNode)

            assert.equal(virtualNode, fakeVirtual, "Should have returned the previously stored virtual node")
        )
    )

    describe("getNodePath(domNode)", ->
        it("returns an array of tagNames, ids and classNames of nodes in top-down order", ->
            rawParentNode = sandbox.document.createElement('div')
            rawParentNode.id = "id"
            virtualParentNode = sandbox.qd._.dom.virtualize(rawParentNode)

            rawChildNode = sandbox.document.createElement('div')
            rawChildNode.className = "child"
            rawChildNode.id = "childId"
            virtualChildNode = virtualParentNode.appendChild(rawChildNode)

            rawGrandChildNode = sandbox.document.createElement('div')
            rawGrandChildNode.className = "grandChild"
            virtualGrandChildNode = virtualChildNode.appendChild(rawGrandChildNode)

            assert.deepEqual(sandbox.qd._.dom.getNodePath(virtualGrandChildNode), ['div#id', 'div#childId.child', 'div.grandChild'])
        )

        it("returns information about the node if it doesn't have any parents", ->
            rawNode = sandbox.document.createElement('div')
            virtualNode = sandbox.qd._.dom.virtualize(rawNode)

            assert.deepEqual(sandbox.qd._.dom.getNodePath(virtualNode), ['div'])
        )
    )

    describe("VirtualDomNode", ->
        describe("constructor(domNode, parentNode)", ->
            it("A given dom node is correctly wrapped", ->
                node = sandbox.document.createElement('div')
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)

                assert.isTrue(virtual instanceof sandbox.qd._.dom.VirtualDomNode, "Virtual nodes should be instances of the virtual dom constructor")
                assert.equal(virtual.getRawNode(), node, "Virtual node wraps the given real node")
                assert.isUndefined(virtual._state.parent, "Parent node creation is deferred")
                assert.isNull(virtual._changes.children, "Child array creation is deferred as well")
                assert.equal(sandbox.qd._.storage.getInternalValue(node, 'virtual'), virtual, "Virtual node is stored on real node")
            )

            it("Virtualizing an already virtualized node returns the previous virtual instance", ->
                node = sandbox.document.createElement('div')
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)

                virtual2 = sandbox.qd._.dom.virtualize(node)
                assert.equal(virtual2, virtual, "Virtualizing again should produce same instance")
            )

            it("Virtualizing after complete data wipe should produce new instance", ->
                node = sandbox.document.createElement('div')
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)

                virtual.dispose()
                assert.isNull(sandbox.qd._.storage.getInternalValue(node, 'virtual'))
                virtual2 = sandbox.qd._.dom.virtualize(node)
                assert.notEqual(virtual2, virtual, "Virtualization after disposal should produce new instance")
            )
        )

        describe("dispose()", ->
            it("dispose removes virtual reference", ->
                node = {}
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                assert.equal(sandbox.qd._.storage.getInternalValue(node, 'virtual'), virtual, "Should have virtual node stored on raw node now")

                virtual.dispose()
                assert.isNull(sandbox.qd._.storage.getInternalValue(node, 'virtual'), "Should have removed virtual reference from node")
            )

            it("dispose calls dispose on all virtual children", ->
                virtual = new sandbox.qd._.dom.VirtualDomNode({})
                children = [{
                    dispose : sinon.spy()
                }, {
                    dispose : sinon.spy()
                }]
                virtual._changes.children = children
                virtual.dispose()

                assert.isNull(virtual._changes, "Should have erased all changes")
                for child in children
                    assert.isTrue(child.dispose.called, "Should have called dispose on the children")

                return
            )
        )

        describe("getParentNode()", ->
            it("getting parent of detached node is null", ->
                node = sandbox.document.createElement('div')
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)

                parentNode = virtual.getParentNode()
                assert.isNull(parentNode, "Detached node should have a null parent")
            )

            it("getting parent of an attached node correctly virtualizes parent", ->
                node = sandbox.document.createElement('div')
                parent = sandbox.document.createElement('div')
                parent.appendChild(node)

                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                parentNode = virtual.getParentNode()
                assert.isNotNull(parentNode, "Should have a parent node")
                assert.isTrue(parentNode instanceof sandbox.qd._.dom.VirtualDomNode, "Result of parent node call should be virtual")
                assert.equal(parentNode.getRawNode(), parent, "Should correctly virtualize parent")
            )
        )

        describe("setParentNode(virtualNode, removeFromOld)", ->
            it("attempting to set a non-virtual parent will error", ->
                throwSpy = sandbox.qd._.errors.throw = sinon.spy()
                node = sandbox.document.createElement('div')
                virtual = sandbox.qd._.dom.virtualize(node)
                virtual.setParentNode({})

                assert.isTrue(throwSpy.calledOnce, "Should have called throw")
            )

            it("setting to a virtual parent correctly stores value", ->
                virtual = new sandbox.qd._.dom.VirtualDomNode({})
                fakeParent = new sandbox.qd._.dom.VirtualDomNode({})
                virtual.setParentNode(fakeParent)
                assert.equal(virtual._state.parent, fakeParent, "Should have parent set now")
            )

            it("setting to a new parent removes from old one", ->
                virtual = new sandbox.qd._.dom.VirtualDomNode({})
                fakeParent = new sandbox.qd._.dom.VirtualDomNode({})
                secondParent = new sandbox.qd._.dom.VirtualDomNode({})
                fakeParent.removeChild = sinon.spy()

                virtual.setParentNode(fakeParent)
                virtual.setParentNode(secondParent)
                assert.equal(virtual._state.parent, secondParent, "Should have parent set to second parent")
                assert.isTrue(fakeParent.removeChild.calledOnce, "Should have called remove child")
            )
        )

        describe("getValue/setValue/clearValues", ->
            it("Should call storage get value and return result", ->
                storageSpy = sinon.stub(sandbox.qd._.storage, 'getValue', -> 1)
                virtual = new sandbox.qd._.dom.VirtualDomNode({})
                assert.equal(virtual.getValue("name", "space"), 1, "Should return the value from the storage call")

                assert.isTrue(storageSpy.calledWith(virtual.getRawNode(), "name", "space"), "Should pass all arguments and the raw node to storage call")
            )

            it("Should call storage set value", ->
                storageSpy = sinon.stub(sandbox.qd._.storage, 'setValue')
                virtual = new sandbox.qd._.dom.VirtualDomNode({})
                virtual.setValue("key", "value", "space")
                assert.isTrue(storageSpy.calledWith(virtual.getRawNode(), "key", "value", "space"), "Should have properly passed call through to set storage")
            )

            it("Should call clear values on storage", ->
                storageSpy = sinon.stub(sandbox.qd._.storage, 'clearValues')
                virtual = new sandbox.qd._.dom.VirtualDomNode({})
                virtual.clearValues()
                assert.isTrue(storageSpy.calledWith(virtual.getRawNode()), "Should have cleared node values")
            )

            it("Should have stored virtual back on node after clear", ->
                virtual = new sandbox.qd._.dom.VirtualDomNode({})
                virtual.clearValues()
                assert.equal(sandbox.qd._.storage.getInternalValue(virtual.getRawNode(), 'virtual'), virtual, "Should have stored virtual back after clearing values")
            )
        )

        describe("getProperty/setProperty", ->
            it("Should get property that has not been overridden directly from the node", ->
                node = {
                    fakeProperty : "cats"
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                assert.equal(virtual.getProperty("fakeProperty"), node.fakeProperty, "Should get value directly from node")
            )

            it("Properties that have been set should only be reflected via the virtual node", ->
                node = {
                    fakeProperty : "cats"
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                virtual.setProperty("fakeProperty", "dogs")
                assert.equal(node.fakeProperty, "cats", "Setting of property should not be reflected on dom node")
                assert.equal(virtual.getProperty("fakeProperty"), "dogs", "Setting of property should be reflected on virtual node")
            )
        )

        describe("getAttribute/setAttribute/hasAttribute/removeAttribute", ->
            it("Should get attributes that have not changed from dom node", ->
                node = {
                    getAttribute : sinon.spy((name) -> return name + name)
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                virtual.getAttribute("a")
                assert.isTrue(node.getAttribute.calledWith("a"), "Should get unchanged attributes from dom")
            )

            it("Changed attributes should only be reflected in the virtual element", ->
                node = {
                    setAttribute : sinon.spy()
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                virtual.setAttribute("a", "b")
                assert.isFalse(node.setAttribute.called, "Should not have called set attribute")
                assert.equal(virtual.getAttribute("a"), "b", "Virtual node should still reflect change")
            )

            it("Checking if node has attribute references node if not set before", ->
                node = {
                    hasAttribute : sinon.spy()
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                virtual.hasAttribute("a")
                assert.isTrue(node.hasAttribute.called, "Should have called has attribute on the node")
            )

            it("Check if node has attribute for modified attribute does not call node", ->
                node = {
                    hasAttribute : sinon.spy()
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                virtual.setAttribute("a", "truth")
                assert.isTrue(virtual.hasAttribute("a"), "Should have attribute")
                assert.isFalse(node.hasAttribute.called, "Should not have called node since change is virtual")
            )

            it("If attribute is removed the change is null", ->
                virtual = new sandbox.qd._.dom.VirtualDomNode({})
                virtual.removeAttribute("first")
                assert.isFalse(virtual.hasAttribute("first"), "Should not have attribute")
            )
        )

        describe("getStyle/setStyle", ->
            it("Should get styles that have not been changed from dom node", ->
                node = {
                    style : {
                        color : "red"
                    }
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                assert.equal(virtual.getStyle("color"), node.style.color, "Should get value directly from raw node")
            )

            it("Changed style values should only be reflected in the virtual element", ->
                node = {
                    style : {
                        color : "red"
                    }
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                virtual.setStyle("color", "blue")
                assert.equal(node.style.color, "red", "Should not have changed the real elements value")
                assert.equal(virtual.getStyle("color"), "blue", "Virtual element should show the change")
            )
        )

        describe("addEventListener/removeEventListener", ->
            it("Event methods are appropriately called through", ->
                node = {
                    addEventListener : sinon.spy()
                    removeEventListener : sinon.spy()
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                virtual.addEventListener("asdf")
                assert.isTrue(node.addEventListener.calledWith("asdf"), "Should have called add event listener")

                virtual.removeEventListener("asdf2")
                assert.isTrue(node.removeEventListener.calledWith("asdf2"), "Should have called remove event listener")
            )
        )

        describe("getChildren()", ->
            it("When no changes have occurred, get children returns normal children wrapped", ->
                node = {
                    children : [{}, {}, {}, {}]
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                children = virtual.getChildren()
                assert.equal(children.length, node.children.length, "Should have same length as real children")
                for child, i in children
                    assert.equal(child.getRawNode(), node.children[i], "Should be the same as original child at index #{i}")
            )

            it("When children have been modified get children is updated but node isnt", ->
                node = {
                    children : []
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                virtual.appendChild({})
                children = virtual.getChildren()
                assert.equal(children.length, 1, "Should have a child in the virtual node")
                assert.equal(node.children.length, 0, "Should not have any children on the real node")
            )
        )

        describe("isChild(child)", ->
            it("Correctly tells if original child is a child", ->
                node = {
                    children : [{}, {}]
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                assert.isTrue(virtual.isChild(node.children[0]), "Should recognize real children")
                assert.isFalse(virtual.isChild({}), "Shouldn't recognize fake children")
            )

            it("Correctly tells modified children are a child", ->
                node = {
                    children : [{}, {}]
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                virtual.removeChild(node.children[1])
                fakeChild = {}
                virtual.appendChild(fakeChild)
                assert.isFalse(virtual.isChild(node.children[1]), "Shouldnt be a child if it has been removed")
                assert.isTrue(virtual.isChild(fakeChild), "Should be a child if it has been added")
            )
        )

        describe("removeChild(child)", ->
            it("Throws an error when removing a non child", ->
                node = {
                    children : [{}]
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                errorSpy = sandbox.qd._.errors.throw = sinon.spy()
                virtual.removeChild({})
                assert.isTrue(errorSpy.called, "Should have thrown an error")
            )

            it("Changes only happen to virtual node", ->
                node = {
                    children : [{}, {}]
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                removedChild = virtual.removeChild(node.children[0])
                assert.equal(node.children.length, 2, "Should still have the child in real node")
                children = virtual.getChildren()
                assert.equal(children.length, 1, "Child should have been removed from virtual children")
                assert.equal(removedChild.getRawNode(), node.children[0], "Should have removed correct child")
                assert.equal(children[0].getRawNode(), node.children[1], "Should have shifted over remaining children")

            )
        )

        describe("appendChild(child)", ->
            it("Appending adds to end of virtual children", ->
                node = {
                    children : []
                }
                fakeChild = {}
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                virtual.appendChild(fakeChild)
                children = virtual.getChildren()

                assert.equal(node.children.length, 0, "Shouldnt show append on real node")
                assert.equal(children.length, 1, "Should show child appended virtually")
                assert.equal(children[0].getRawNode(), fakeChild, "Fake child should be in first position")
            )

            it("Appending an already attached node should move it to the end", ->
                node = {
                    children : [{}, {}]
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                virtual.appendChild(node.children[0])
                children = virtual.getChildren()

                assert.equal(children.length, 2, "Should still show two children virtually")
                assert.equal(children[0].getRawNode(), node.children[1], "Should have last child in first position now")
                assert.equal(children[1].getRawNode(), node.children[0], "Should have first child in last position now")
            )
        )

        describe("insertChild(child, referenceNode)", ->
            it("giving a node that is not a child as reference errors", ->
                node = {
                    children : []
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                errorSpy = sandbox.qd._.errors.throw = sinon.spy()
                virtual.insertBefore({}, {})
                assert.isTrue(errorSpy.called, "Should have thrown an error because reference node is not a child node")
            )

            it("reference node is correctly used", ->
                node = {
                    children : [{}]
                }
                fakeNode = {}
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                virtual.insertBefore(fakeNode, node.children[0])
                children = virtual.getChildren()
                assert.equal(children.length, 2, "Should have two children now")
                assert.equal(children[0].getRawNode(), fakeNode, "Should have inserted in first position")
            )

            it("inserting existing node that is before reference node moves it among children", ->
                node = {
                    children : [{}, {}, {}]
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                virtual.insertBefore(node.children[0], node.children[2])
                children = virtual.getChildren()
                assert.equal(children.length, 3, "Should not change child length")
                assert.equal(children[0].getRawNode(), node.children[1], "Should have removed item from front")
                assert.equal(children[1].getRawNode(), node.children[0], "Should have positioned in front of reference item")
            )

            it("inserting existing node that is after reference node moves it among children", ->
                node = {
                    children : [{}, {}, {}]
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                virtual.insertBefore(node.children[2], node.children[1])
                children = virtual.getChildren()
                assert.equal(children.length, 3, "Should not change child length")
                assert.equal(children[1].getRawNode(), node.children[2], "Should have removed item from end")
                assert.equal(children[2].getRawNode(), node.children[1], "Should have positioned in front of reference item")
            )

            it("inserting into current place does nothing", ->
                node = {
                    children : [{}, {}]
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                virtual.insertBefore(node.children[0], node.children[1])
                children = virtual.getChildren()
                assert.equal(children.length, 2, "Should still be two")
                assert.equal(children[0].getRawNode(), node.children[0], "Should still be in same order")
            )

            it("not providing a reference item falls back to an append", ->
                node = { children : [] }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                appendSpy = sinon.stub(virtual, 'appendChild')
                virtual.insertBefore({})
                assert.isTrue(appendSpy.called, "Should have called append since no reference node was given")
            )
        )

        describe("clearChildren/setChildren", ->
            it("clearing children only affects virtual state", ->
                node = {
                    children : [{}, {}, {}]
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                virtual.clearChildren()
                children = virtual.getChildren()

                assert.equal(children.length, 0, "Should have no virtual children")
                assert.equal(node.children.length, 3, "Should still have all children in raw node")
            )

            it("setting children completely wipes previous children", ->
                node = {
                    children : [{}]
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                replacements = [{}]
                oldChild = node.children[0]
                virtual.setChildren(replacements)
                children = virtual.getChildren()

                assert.equal(node.children[0], oldChild, "Should still have original child in node")
                assert.equal(children.length, replacements.length, "Should have same number of children as replacement array")
                assert.equal(children[0].getRawNode(), replacements[0], "Should have replacement in virtual children")
            )
        )

        describe("generatePatch()", ->
            it("generate patch on a disposed element is null", ->
                virtual = new sandbox.qd._.dom.VirtualDomNode({})
                virtual.dispose()
                assert.isNull(virtual.generatePatch(), "Patch should be null")
            )

            it("generate patch on an element without modifications returns null", ->
                virtual = new sandbox.qd._.dom.VirtualDomNode({})
                assert.isNull(virtual.generatePatch(), "Should be a null patch")
            )

            it("generate patch returns all internal changes and clears internal state", ->
                node = {}
                properties = {}
                attributes = {}
                styles = {}

                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                virtual._state.hasModifications = true
                virtual._changes = {
                    properties : properties
                    attributes : attributes
                    styles : styles
                    children : null
                }

                patch = virtual.generatePatch()
                assert.equal(patch.node, node, "Should have returned raw node in patch")
                assert.equal(patch.properties, properties, "Should have returned properties stored in virtual node")
                assert.equal(patch.attributes, attributes, "Should have returned attributes in virtual node")
                assert.equal(patch.styles, styles, "Should have returned styles in virtual node")
                assert.equal(patch.children.length, 0, "Should have no children changes")

                assert.notEqual(virtual._changes.properties, properties, "Should have constructed a new properties object")
                assert.notEqual(virtual._changes.attributes, attributes, "Should have constructed a new attributes object")
                assert.notEqual(virtual._changes.styles, styles, "Should have constructed a new styles object")
                assert.isNull(virtual._changes.children, "Should erase all children changes")
            )
        )

        describe("_generateChildrenActions()", ->
            generateChildren = (count) ->
                return (sandbox.document.createElement('div') for i in [0...count])

            it("a current child that is removed results in a remove action", ->
                node = {
                    children : generateChildren(5)
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                removeChild = virtual.removeChild(node.children[0])
                assert.equal(removeChild.getRawNode(), node.children[0], "Removed child virtual node should be returned")

                actions = virtual._generateChildrenActions()
                assert.equal(actions.length, 1, "Should have one action")
                assert.equal(actions[0].type, "remove", "Should have a remove action")
                assert.equal(actions[0].value, removeChild.getRawNode(), "Should have removed child as value for action")
            )

            it("appending a child to an empty node causes an insert at the end", ->
                node = {
                    children : []
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                rawChild = sandbox.document.createElement('div')
                appendChild = virtual.appendChild(rawChild)

                assert.equal(appendChild.getRawNode(), rawChild, "Should return the appended virtual child")

                actions = virtual._generateChildrenActions()
                assert.equal(actions.length, 1, "Should have one action")
                assert.equal(actions[0].type, "insert", "Should be an insert action")
                assert.equal(actions[0].value, appendChild.getRawNode(), "Should have inserted child as value for action")
                assert.isNull(actions[0].follows, "Should not follow anything as children was empty")
            )

            it("appending a child to a set of children causes an insert with correct follow", ->
                node = {
                    children : generateChildren(1)
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                rawChild = sandbox.document.createElement('div')
                appendChild = virtual.appendChild(rawChild)

                assert.equal(appendChild.getRawNode(), rawChild, "Should return the appended virtual child")

                actions = virtual._generateChildrenActions()
                assert.equal(actions.length, 1, "Should have one action")
                assert.equal(actions[0].type, "insert", "Should be an insert action")
                assert.equal(actions[0].value, appendChild.getRawNode(), "Should have inserted child as value for action")
                assert.equal(actions[0].follows, node.children[node.children.length - 1], "Should follow last node")
            )

            it("inserting children sets correct follow", ->
                node = {
                    children : generateChildren(4)
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                rawChild = sandbox.document.createElement('div')
                insertedChild = virtual.insertBefore(rawChild, node.children[2])

                assert.equal(insertedChild.getRawNode(), rawChild, "Should return the inserted virtual child")

                actions = virtual._generateChildrenActions()
                assert.equal(actions.length, 1, "Should have one action")
                assert.equal(actions[0].type, "insert", "Should be an insert action")
                assert.equal(actions[0].value, insertedChild.getRawNode(), "Should have inserted child as value for action")
                assert.equal(actions[0].follows, node.children[1], "Should have follow set to node inserted before")
            )

            it("if applying changes backwards is cheaper the actions are backwards", ->
                node = {
                    children : generateChildren(3)
                }
                virtual = new sandbox.qd._.dom.VirtualDomNode(node)
                rawMovedChild = node.children[0]
                insertedChild = virtual.appendChild(rawMovedChild)

                assert.equal(insertedChild.getRawNode(), rawMovedChild, "Should return the inserted virtual child")

                actions = virtual._generateChildrenActions()
                assert.equal(actions.length, 1, "Should have one action since backwards only causes one")
            )
        )
    )
)
