describe("Quickdraw.Internal.Binding", ->
    describe("getBindingFunction(node):", ->
        it("Given a null node, nothing is done and null is returned", ->
            result = sandbox.qd._.binding.getBindingFunction(null)
            assert.isNull(result, "Null is returned for null input")
        )

        it("Given a node that has no getAttribute, returns null", ->
            comment = sandbox.document.createComment("test")
            result = sandbox.qd._.binding.getBindingFunction(comment)
            assert.isNull(result, "Null is returned for non-node input")
        )

        it("Given a node that has no binding, null returned", ->
            node = sandbox.document.createElement("div")
            spy = sinon.spy(node, "getAttribute")
            result = sandbox.qd._.binding.getBindingFunction(node)
            assert.isNull(result, "Null returned when no data-bind attribute specified")
            assert.isTrue(spy.calledOnce, "getAttribute was called")
        )

        it("If a node binding attribute throws an error on parse because of syntax", ->
            node = sandbox.document.createElement("div")
            node.setAttribute(sandbox.qd.getConfig('bindingAttribute'), '{ this fails }')
            spy = sandbox.qd._.errors.throw = sinon.spy()
            sandbox.qd._.binding.getBindingFunction(node)

            assert.isTrue(spy.calledOnce, "Should have called the error method")
        )

        it("Valid binding string parsed to function and returned", ->
            node = sandbox.document.createElement("div")
            node.setAttribute(sandbox.qd.getConfig('bindingAttribute'), 'data : first + second')
            result = sandbox.qd._.binding.getBindingFunction(node)

            parsedResult = result({
                first : 1
                second : 2
                $data : {}
            })

            assert.equal(parsedResult.data, 3, "Should properly parse with the context")
        )
    )

    describe("getEvaluatedBindingObject(domNode, bindingContext)", ->
        it("returns null if there is no binding function", ->
            functionSpy = sinon.stub(sandbox.qd._.binding, "getBindingFunction", -> return null)

            assert.isNull(sandbox.qd._.binding.getEvaluatedBindingObject({}, {}), "Should return null since there is no binding function")
        )

        it("Catches any errors thrown in the binding function", ->
            bindingContext = {}
            rawNode = sandbox.document.createElement('div')
            virtualNode = sandbox.qd._.dom.virtualize(rawNode)

            functionSpy = sinon.stub(sandbox.qd._.binding, "getBindingFunction", ->
                return (context, node) ->
                    assert.equal(context, bindingContext, "Binding context should be the first thing passed to the binding function")
                    assert.equal(node, rawNode, "Should pass the unvirtualized node to the binding function")
                    throw "Things are not what they seem"
            )

            errorSpy = sandbox.qd._.errors.throw = sinon.spy()

            assert.isNull(sandbox.qd._.binding.getEvaluatedBindingObject(virtualNode, bindingContext), "Should return null if an error is thrown")

            assert.isTrue(errorSpy.called, "Should have thrown an error through quickdraw error class")
        )

        it("Correctly returns evaluated binding object if all goes well", ->
            fakeBindingObject = {}

            functionSpy = sinon.stub(sandbox.qd._.binding, "getBindingFunction", -> return -> fakeBindingObject)

            assert.equal(sandbox.qd._.binding.getEvaluatedBindingObject({}, {}), fakeBindingObject, "Should correctly return binding object")
        )
    )

    describe("bindModel(viewModel, domRoot, context)", ->
        it("Errors on invalid viewmodel", ->
            errorSpy = sinon.stub(sandbox.qd._.errors, "throw")
            sandbox.qd._.binding.bindModel(null)

            assert.isTrue(errorSpy.calledOnce, "Should have thrown an error via quickdraw about missing view model")
        )

        it("Throws an error for undefined binding context", ->
            errorSpy = sinon.stub(sandbox.qd._.errors, "throw")
            sandbox.qd._.binding.bindModel({}, {})

            assert.isTrue(errorSpy.calledOnce, "Should have thrown an error via quickdraw about missing binding context")
        )

        it("Throws an error when view model is not properly wrapped", ->
            errorSpy = sinon.stub(sandbox.qd._.errors, "throw")
            sandbox.qd._.binding.bindModel({}, {}, {})

            assert.isTrue(errorSpy.calledOnce, "Should have thrown an error via quickdraw about incorrect view model")
        )

        it("Correctly updates the quickdraw state to reflect the new viewmodel", ->
            vm = sandbox.qd._.models.create({})
            node = {}
            context = {}

            sandbox.qd._.dom.virtualize = (dom) -> return dom
            sandbox.qd._.binding.bindDomTree = ->
            modelSpy = sandbox.qd._.models.setParent = sinon.spy()
            restoreSpy = sinon.stub()
            updateState = sinon.spy(sandbox.qd._, "updateCurrentState")

            sandbox.qd._.binding.bindModel(vm, node, context)

            assert.isTrue(modelSpy.calledWith(vm, null), "Should have called set parent for new model")
            assert.isTrue(updateState.calledOnce, "Should have called update state")
            assert.equal(updateState.getCall(0).args[0].model, vm, "Should have updated the current view model in the state")
            assert.isNull(sandbox.qd._.state.current.model, "Should have restored the previous view model after binding")
        )

        it("Always virtualizes the given dom node", ->
            vm = sandbox.qd._.models.create({})
            node = {}
            context = {}

            virtualSpy = sandbox.qd._.dom.virtualize = sinon.spy((dom) -> return 1)
            bindSpy = sandbox.qd._.binding.bindDomTree = sinon.stub()
            sandbox.qd._.models.setParent = ->

            sandbox.qd._.binding.bindModel(vm, node, context)
            assert.isTrue(virtualSpy.calledWith(node), "Should have tried to virtualize the given dom node")
            assert.isTrue(bindSpy.calledWith(1, context), "Should have passed virtual dom node through")
        )

        it("Errors when view model has changed during binding", ->
            vm = sandbox.qd._.models.create({})
            node = sandbox.document.createElement('div')
            context = {}
            errorSpy = sinon.stub(sandbox.qd._.errors, "throw")

            sandbox.qd._.models.setParent = ->
            sandbox.qd._.binding.bindDomTree = ->
                sandbox.qd._.state.current.model = "fake"

            sandbox.qd._.binding.bindModel(vm, node, context)
            assert.isTrue(errorSpy.calledOnce, "Should have thrown an error via quickdraw")
        )
    )

    describe("bindDomTree(domRoot, bindingContext):", ->
        it("Does not recurse to children if sub call returns false", ->
            domNode = {
                getChildren : sinon.spy()
            }
            bindNodeSpy = sinon.stub(sandbox.qd._.binding, "bindDomNode", -> return false)

            sandbox.qd._.binding.bindDomTree(domNode, {})

            assert.isTrue(bindNodeSpy.called, "Should call dom node binding method")
            assert.isFalse(domNode.getChildren.called, "Should not call get children since dom node binding returned false")
        )

        it("Does recurse to children if sub call returns true", ->
            fakeChildren = [{}, {}]
            domNode = {
                getChildren : sinon.spy(-> return fakeChildren)
            }
            bindNodeSpy = sinon.stub(sandbox.qd._.binding, "bindDomNode", -> return true)

            originalBindTree = sandbox.qd._.binding.bindDomTree
            bindTreeSpy = sinon.stub(sandbox.qd._.binding, "bindDomTree")

            originalBindTree.call(sandbox.qd._.binding, domNode, {})

            assert.isTrue(bindNodeSpy.called, "Should call dom node binding method")
            assert.isTrue(domNode.getChildren.called, "Should call get children since dom node binding returned true")
            assert.equal(bindTreeSpy.callCount, fakeChildren.length, "Should hve called bind dom tree for each child")
        )
    )

    describe("bindDomNode(domNode, bindingContext)", ->
        it("Does no binding if there is no binding object", ->
            node = sandbox.document.createElement('div')
            virtualNode = sandbox.qd._.dom.virtualize(node)

            storageSpy = sinon.stub(sandbox.qd._.storage, "setInternalValue")
            functionSpy = sinon.stub(sandbox.qd._.binding, "getEvaluatedBindingObject", -> return null)

            assert.isTrue(sandbox.qd._.binding.bindDomNode(virtualNode, {}), "When no binding function bindDomNode should return true")
            assert.isFalse(storageSpy.called, "Should not have called storage spy since there was no binding object")
        )

        it("Marks node with all handlers in the binding function and starts them as dirty", ->
            fakeNode = {}
            fakeContext = {}
            fakeBindingObject = {
                first : "yes"
                second : "no"
            }

            sandbox.qd._.binding.getEvaluatedBindingObject = -> return fakeBindingObject
            sandbox.qd._.state.binding.order = ["first", "second"]
            initializeSpy = sinon.stub(sandbox.qd._.handlers, "getInitialize")
            updateSpy = sinon.stub(sandbox.qd._.binding, "updateDomNode", -> return true)
            storageSpy = sinon.stub(sandbox.qd._.storage, "setInternalValue", ->
                assert.isFalse(updateSpy.called, "Should not call update spy before setting internal value")
            )

            sandbox.qd._.binding.bindDomNode(fakeNode, fakeContext)

            assert.isTrue(initializeSpy.calledWith("first"), "Should have requested the first handler at some point")
            assert.isTrue(initializeSpy.calledWith("second"), "Should have requested the second handler at some point")
            assert.isTrue(storageSpy.calledOnce, "Should set handlers on internal storage")
            assert.equal(storageSpy.firstCall.args.length, 3, "Should have passed three arguments to storage")
            assert.equal(storageSpy.firstCall.args[0], fakeNode, "Should store handlers on node")
            assert.equal(storageSpy.firstCall.args[1], 'handlers', "Should store under the key handlers")
            handlerObject = storageSpy.firstCall.args[2]
            assert.isTrue(handlerObject.first, "Should have marked the first handler as dirty")
            assert.isTrue(handlerObject.second, "Should have marked the second handler as dirty")
            assert.isTrue(updateSpy.calledWith(fakeNode, fakeContext, fakeBindingObject), "Should call update dom node after setting handlers object")
        )
    )

    describe("updateDomNode(domNode, bindingContext, bindingObject = null)", ->
        it("Does no binding if there is no binding object", ->
            domNode = {}
            storageSpy = sinon.stub(sandbox.qd._.storage, "getInternalValue")
            functionSpy = sinon.stub(sandbox.qd._.binding, "getEvaluatedBindingObject", -> return null)

            assert.isTrue(sandbox.qd._.binding.updateDomNode(domNode, {}), "Should allow to continue to children when no binding function")
            assert.isTrue(functionSpy.called, "Should call to get binding object")
            assert.isFalse(storageSpy.called, "Should not have called the storage module as it should have returned early")
        )

        it("Evaluates binding object only if not given one", ->
            domNode = {}
            bindingContext = {}
            bindingSpy = sinon.stub(sandbox.qd._.binding, "getEvaluatedBindingObject", -> return null)

            sandbox.qd._.binding.updateDomNode(domNode, bindingContext)
            assert.isTrue(bindingSpy.calledWith(domNode, bindingContext), "Should have called binding object evaluater since no object was given")

            bindingSpy.reset()

            sandbox.qd._.state.binding.order = []
            sandbox.qd._.binding.updateDomNode(domNode, bindingContext, {})
            assert.isFalse(bindingSpy.called, "Should not have called binding function since object was given")
        )

        it("Calls any handlers that are marked to receive updates", ->
            domNode = {}
            handlerState = {
                first : true
                second : false
                third : true
            }
            sandbox.qd._.storage.setInternalValue(domNode, 'handlers', handlerState)
            sandbox.qd._.state.binding.order = ["first", "second", "third", "fourth"]
            updateSpy = sinon.stub(sandbox.qd._.handlers, "getUpdate", -> return ->)

            result = sandbox.qd._.binding.updateDomNode(domNode, {}, {
                first : 1
                second : 2
                third : 3
            })

            assert.isTrue(result, "Since no handlers returned a value, should continue should be true")

            assert.isTrue(updateSpy.calledWith('first'), "Should have gotten the first update method at some point")
            assert.isTrue(updateSpy.calledWith('third'), "Should have gotten the third update method at some point")
            assert.isFalse(handlerState.first, "Should set the dirty state to false for first handler")
            assert.isFalse(handlerState.third, "Should set the dirty state to false for third handler")
        )

        it("If an update is false the result of the function call is false", ->
            domNode = {}
            sandbox.qd._.storage.setInternalValue(domNode, 'handlers', { first : true })
            sandbox.qd._.state.binding.order = ["first"]
            sandbox.qd._.handlers.getUpdate = -> return -> false

            assert.isFalse(sandbox.qd._.binding.updateDomNode(domNode, {}, { first : 2 }), "Should result in false since an update method returned false")
        )
    )

    describe("unbindDomTree(domNode)", ->
        it("calls remove dependency on any observables registered on node", ->
            node = sandbox.document.createElement('div')
            removeSpy = sinon.spy()
            sandbox.qd._.observables.removeDependency = removeSpy
            sandbox.qd._.storage.setInternalValue(node, 'observables', [{}, {}])

            sandbox.qd._.binding.unbindDomTree(node)

            assert.isTrue(removeSpy.calledTwice, "Should call remove dependency for each observable")
        )

        it("calls clear storage for quickdraw storage", ->
            node = sandbox.document.createElement('div')
            virtualNode = sandbox.qd._.dom.virtualize(node)
            clearSpy = sinon.spy(virtualNode, 'clearValues')

            sandbox.qd._.binding.unbindDomTree(node)

            assert.isTrue(clearSpy.called, "Should have cleared all values via virtual node")
        )

        it("should call unbind on all children", ->
            node = sandbox.document.createElement('div')
            children = []
            for i in [0 ... 4]
                child = sandbox.document.createElement('span')
                node.appendChild(child)
                children.push(child)

            callSpy = sandbox.qd._.binding.unbindDomTree = sinon.spy(sandbox.qd._.binding.unbindDomTree)

            sandbox.qd._.binding.unbindDomTree(node)

            assert.equal(callSpy.callCount, 5, "Should be called once for node and once for each child")
            for child, i in children
                assert.equal(callSpy.getCall(i + 1).args[0].getRawNode(), child, "Should call in child order")
        )

        it("calls cleanup method for any handler that needs it", ->
            handlers = {
                one : true,
                two : true,
                three : true
            }
            node = sandbox.document.createElement('div')
            sandbox.qd._.storage.setInternalValue(node, 'handlers', handlers)

            firstCleanSpy = sinon.spy()
            thirdCleanSpy = sinon.spy()
            sandbox.qd.registerBindingHandler("one", {
                initialize : {}
                cleanup : firstCleanSpy
            })
            sandbox.qd.registerBindingHandler("two", {
                initialize : {}
            })
            sandbox.qd.registerBindingHandler("three", {
                initialize : {}
                cleanup : thirdCleanSpy
            })

            getCleanupSpy = sinon.spy(sandbox.qd._.handlers, 'getCleanup')

            sandbox.qd._.binding.unbindDomTree(node)

            assert.equal(getCleanupSpy.callCount, 3, "Should have got three calls for cleanup handlers")
            for name, bool of handlers
                assert.isTrue(getCleanupSpy.calledWith(name), "Should have asked for '#{name}' cleanup handler")

            assert.isTrue(firstCleanSpy.calledWith(sandbox.qd._.dom.virtualize(node)), "Should have called first handler cleanup method")
            assert.isTrue(thirdCleanSpy.calledWith(sandbox.qd._.dom.virtualize(node)), "Should have called third handler cleanup method")
        )
    )
)
