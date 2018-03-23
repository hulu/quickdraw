describe("Quickdraw.Bindings.Foreach", ->
    it("Handler is bound to foreach keyword", assertModuleBound("foreach"))

    createElement = ->
        dom = sandbox.document.createElement("div")
        template = sandbox.document.createElement("span")
        dom.appendChild(template)
        return sandbox.qd._.dom.virtualize(dom)

    createContext = (data) ->
        model = sandbox.qd._.models.create(data)
        return sandbox.qd._.context.create(model)

    initializeElement = (data, dom, context) ->
        initialize = qdGetInitialize("foreach")
        initialize(data, dom, context)
        updateElement(data, dom, context)

    updateElement = (data, dom, context) ->
        update = qdGetUpdate("foreach")
        update(data, dom, context)

    describe("Single Overall Template", ->
        it("Creates an element for each element in an array", ->
            items = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
            dom = createElement()

            stub = sinon.stub(sandbox.qd._.binding, "bindModel")

            initializeElement(items, dom, createContext(items))

            assert.equal(stub.callCount, items.length, "Each new element has bindings applied")

            newChildren = dom.getChildren()
            assert.equal(newChildren.length, items.length, "Each new element was added to page")
            for i in [0 ... items.length]
                assert.equal(stub.getCall(i).args[0].raw, items[i], "Items called in the order specified")
                assert.equal(stub.getCall(i).args[1], newChildren[i], "Item added to parent in correct order")
        )

        it("Binding context modified correctly", ->
            items = [1]
            dom = createElement()

            stub = sinon.stub(sandbox.qd._.binding, "bindModel")

            initializeElement(items, dom, createContext(items))

            assert.isTrue(stub.calledOnce, "Apply bindings correctly called")
            callData = stub.getCall(0)
            assert.equal(callData.args[2].$index(), 0, "Index correctly passed")
            assert.equal(callData.args[2].$data, items[0], "Data updated")
        )

        it("Manually changing elements does not prevent template from being used on next apply", ->
            items = [1, 2, 3, 4, 5]
            dom = createElement()
            stub = sinon.stub(sandbox.qd._.binding, "bindModel")

            initializeElement(items, dom, createContext(items))

            assert.equal(stub.callCount, items.length, "Each new element has bindings applied")

            dom.clearChildren()

            newElm = sandbox.document.createElement("a")
            newElm = dom.appendChild(newElm)

            items = [6, 7, 8, 9, 10]
            stub.reset()

            updateElement(items, dom, createContext(items))

            newChildren = dom.getChildren()
            assert.equal(stub.callCount, items.length, "Each item again bound")
            assert.isFalse(newElm in newChildren, "Added item is removed")

            for i in [0 ... items.length]
                assert.equal(stub.getCall(i).args[0].raw, items[i], "Items called in the order given")
                assert.equal(stub.getCall(i).args[1], newChildren[i], "Item added to parent in order")
                assert.equal(newChildren[i].getProperty('nodeName').toLowerCase(), "span", "Item is proper template")
        )

        it("Elements that remain unchanged are not rebound", ->
            items = [1, 2, 3, 4]
            dom = createElement()
            stub = sinon.stub(sandbox.qd._.binding, "bindModel")

            initializeElement(items, dom, createContext(items))

            assert.equal(stub.callCount, items.length, "Each new element has binding applied")

            items.push(5)
            stub.reset()
            updateElement(items, dom, createContext(items))
            assert.equal(stub.callCount, 1, "Only new item is bound")
            assert.equal(stub.getCall(0).args[0].raw, items[items.length - 1], "Last item is properly bound")
            assert.equal(dom.getChildren()[items.length - 1].getProperty('nodeName').toLowerCase(), "span", "Item is proper template")
        )

        it("Elements that change indexes are not fully rebound", ->
            items = [1, 2, 3, 4]
            dom = createElement()
            stub = sinon.stub(sandbox.qd._.binding, "bindModel")

            initializeElement(items, dom, createContext(items))

            assert.equal(stub.callCount, items.length, "Should bind all four original items")

            contexts = []
            for child in dom.getChildren()
                context = child.getValue('context', 'foreach')
                context.$index = sinon.spy()
                contexts.push(context)

            items.unshift(0)
            stub.reset()
            updateElement(items, dom, createContext(items))

            assert.equal(stub.callCount, 1, "Only one item is fully bound as the rest still exist")
            boundElement = stub.getCall(0).args[1]

            for context, i in contexts
                assert.isTrue(context.$index.calledWith(i + 1), "Should have updated index in non-fully bound items")

            return
        )

        it("Elements are correctly reused without returning any templates", ->
            items = [1, 2, 3, 4]
            dom = createElement()
            stub = sinon.stub(sandbox.qd._.binding, "bindModel")

            initializeElement(items, dom, createContext(items))
            assert.equal(stub.callCount, items.length, "Each new element has binding applied")

            # store all the children currently there
            children = dom.getChildren()

            items.push(5)
            stub.reset()
            returnSpy = sinon.spy(sandbox.qd._.templates, "return")
            updateElement(items, dom, createContext(items))
            assert.equal(stub.callCount, 1, "Only new item is bound")
            assert.equal(stub.getCall(0).args[0].raw, items[items.length - 1], "Last item is properly bound")
            assert.isFalse(returnSpy.called, "Should not return any templates since they are directly reused")

            # ensure all the original nodes are the same ones in the tree
            newChildren = dom.getChildren()
            for i in [0 ... children.length]
                assert.equal(newChildren[i], children[i], "Child at index #{i} is properly reused")
        )

        it("Templates are reused with complete data replacement", ->
            items = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
            dom = createElement()
            stub = sinon.stub(sandbox.qd._.binding, "bindModel")

            initializeElement(items, dom, createContext(items))
            children = dom.getChildren()

            assert.equal(stub.callCount, items.length, "Each new element has bindings applied")
            for child, i in children
                model = child.getValue('model', 'foreach')
                assert.equal(stub.getCall(i).args[1], child, "Should have bound #{i} child")
                assert.equal(model, items[i], "Incorrect item bound for child #{i}")

            stub.reset()

            items = [11, 12, 13, 14, 15, 16, 17]
            updateElement(items, dom, createContext(items))
            newChildren = dom.getChildren()

            assert.equal(stub.callCount, items.length, "Each new element has binding applied")
            for child, i in newChildren
                model = child.getValue('model', 'foreach')
                assert.equal(stub.getCall(i).args[1], child, "Should have bound #{i} child")
                assert.equal(model, items[i], "Incorrect item bound for child #{i}")
                assert.equal(child, children[i], "Should have completely reused child at position #{i}")

            return
        )
    )

    describe("Multiple Templates", ->
        registerCustomTemplate = (templateName) ->
            nodes = []
            nodes.push(sandbox.document.createElement('div'))
            nodes.push(sandbox.document.createElement('div'))
            sandbox.qd.registerTemplate(templateName, nodes)

        it("If template is specified in model it is used instead of main template", ->
            templateName = "otherTemplate"
            items = [{template : templateName}, {template : templateName}]
            registerCustomTemplate(templateName)
            dom = createElement()

            getSpy = sinon.spy(sandbox.qd._.templates, "get")

            initializeElement({ data : items, templatesFromModels : true }, dom, createContext(items))
            children = dom.getChildren()
            assert.equal(getSpy.callCount, items.length, "Should have requested two templates")
            assert.isTrue(getSpy.calledWith("otherTemplate"), "Should have requested manual template once")
            assert.equal(children.length, 4, "Should have 4 child elements")
        )

        it("cleanup correctly returns each template type", ->
            templateName = "otherTemplate"
            items = [{template : templateName}, {template : templateName}]
            registerCustomTemplate(templateName)
            dom = createElement()

            returnSpy = sinon.spy(sandbox.qd._.templates, "return")

            initializeElement({ data : items, templatesFromModels : true }, dom, createContext(items))
            children = dom.getChildren()
            assert.equal(children.length, 4, "Should have 4 child elements")

            cleanup = qdGetCleanup("foreach")
            cleanup(dom)

            registeredName = sandbox.qd._.templates.resolve(templateName)

            assert.equal(returnSpy.callCount, 2, "Should have returned two templates")
            assert.equal(returnSpy.getCall(0).args[0], registeredName, "Should have returned custom template")
            assert.equal(returnSpy.getCall(1).args[0], registeredName, "Should have returned custom template")
        )
    )

    describe("Cleanup", ->
        it("Cleanup properly restores original template", ->
            items = [1, 2, 3, 4]
            dom = createElement()
            template = dom.getChildren()[0].getProperty('outerHTML')

            initializeElement(items, dom, createContext(items))
            assert.equal(dom.getChildren().length, 4, "Should have 4 child elements")

            # add extra child to ensure it cleans it up
            dom.appendChild(sandbox.qd._.dom.virtualize(sandbox.document.createElement('div')))

            cleanup = qdGetCleanup("foreach")
            cleanup(dom)

            assert.equal(dom.getChildren().length, 1, "Should only have 1 child elements")
            assert.equal(dom.getChildren()[0].getProperty('outerHTML'), template, "Should have restored the original template")
        )
    )
)
