describe("Quickdraw.Bindings.With", ->
    it("Handler is bound to with keyword", assertModuleBound("with"))

    it("Binding context appropriately extended", ->
        dom = createVirtualElement()
        dom.appendChild(sandbox.document.createElement("span"))
        model = sandbox.qd._.models.create({
            submodel : { everything : true }
        })

        initialize = qdGetInitialize("with")
        initialize(model.raw.submodel, dom)

        assert.equal(dom.getChildren().length, 0, "Should have no children after intialize")

        stub = sinon.stub(sandbox.qd._.binding, "bindModel")
        callback = qdGetUpdate("with")
        callback(model.raw.submodel, dom, sandbox.qd._.context.create(model))

        assert.equal(dom.getChildren().length, 1, "Should have child after update")
        assert.isTrue(stub.calledOnce, "Apply bindings correctly called")
        context = stub.getCall(0).args[2]
        assert.equal(context.$data, model.raw.submodel, "Context modified to use submodel")
        assert.equal(context.$root, model.raw, "Original model still the root")
        assert.equal(context.$parents.length, 1, "Only one parent")
        assert.equal(context.$parent, model.raw, "Parent model properly tied")
        assert.equal(context.$rawData, model.raw.submodel, "Raw data updated properly")
    )

    it("Non bindable children skipped", ->
        dom = createVirtualElement()
        element = sandbox.document.createElement("span")
        dom.appendChild(element)
        dom.appendChild(sandbox.document.createComment("test"))
        model = sandbox.qd._.models.create({})

        stub = sinon.stub(sandbox.qd._.binding, "bindModel")
        callback = qdGetUpdate("with")
        callback({}, dom, sandbox.qd._.context.create(model))
        
        assert.isTrue(stub.calledOnce, "Apply bindings only called once for non comment")
        assert.equal(stub.getCall(0).args[1].getRawNode(), element, "Non comment node passed")
    )

    it("If data doesn't change on update rebind does not occur", ->
        bindingData = {}
        model = sandbox.qd._.models.create({})
        context = sandbox.qd._.context.create(model)
        dom = createVirtualElement()
        element = sandbox.document.createElement("span")
        dom.appendChild(element)

        stub = sinon.stub(sandbox.qd._.binding, "bindModel")
        initialize = qdGetInitialize("with")
        initialize(bindingData, dom)
        update = qdGetUpdate("with")
        update(bindingData, dom, context)

        assert.isTrue(stub.calledOnce, "Should have applied bindings to element")

        stub.reset()
        update(bindingData, dom, context)
        assert.isFalse(stub.called, "Should not have called stub as binding data did not change")
    )

    it("Null binding data results in children being removed", ->
        dom = createVirtualElement()
        dom.appendChild(sandbox.document.createElement("span"))
        dom.appendChild(sandbox.document.createElement("div"))

        initialize = qdGetInitialize("with")
        initialize({}, dom)

        assert.equal(dom.getChildren().length, 0, "Should have no children after initialize")

        callback = qdGetUpdate("with")
        callback({}, dom, sandbox.qd._.context.create({}))

        assert.equal(dom.getChildren().length, 2, "Should have children after update")

        clearSpy = sinon.spy(dom, 'clearChildren')
        callback(null, dom, null)

        assert.isTrue(clearSpy.called, "Should have cleared the children as data has changed")
        assert.equal(dom.getChildren().length, 0, "Should have no children after update to null")
    )

    it("If data has changed but template has not children are not cleared", ->
        dom = createVirtualElement()
        dom.appendChild(sandbox.document.createElement("span"))
        dom.appendChild(sandbox.document.createElement("div"))

        myData = {}
        myData2 = {}

        initialize = qdGetInitialize("with")
        initialize(myData, dom)

        callback = qdGetUpdate("with")
        callback(myData, dom, sandbox.qd._.context.create(myData))

        assert.equal(dom.getChildren().length, 2, "Should have no children after update")

        clearSpy = sinon.spy(dom, 'clearChildren')
        callback(myData2, dom, sandbox.qd._.context.create(myData2))

        assert.isFalse(clearSpy.called, "Should not have called clear children as template did not change")
        assert.equal(dom.getChildren().length, 2, "Should still have two children after update")
    )

    it("Original template returned on cleanup", ->
        dom = createVirtualElement()
        dom.appendChild(sandbox.document.createElement("span"))
        model = sandbox.qd._.models.create({})

        initialize = qdGetInitialize("with")
        initialize({}, dom)

        assert.equal(dom.getChildren().length, 0, "Should have no children after init")

        cleanup = qdGetCleanup("with")
        cleanup(dom)

        assert.equal(dom.getChildren().length, 1, "Should have added child back after cleanup")
    )

    it("Using custom template is respected", ->
        dom = createVirtualElement()
        dom.appendChild(sandbox.document.createElement("span"))
        realModel = {
            template : 'fakeTemplate'
        }
        model = sandbox.qd._.models.create({
            model : realModel
            templateFromModel : true
        })
        bindSpy = sinon.stub(sandbox.qd._.binding, 'bindModel')

        template = [sandbox.document.createElement("div")]
        sandbox.qd.registerTemplate('fakeTemplate', template)

        initialize = qdGetInitialize("with")
        initialize(model.raw, dom)

        assert.equal(dom.getChildren().length, 0, "Should have no children after init")

        callback = qdGetUpdate("with")
        callback(model.raw, dom, sandbox.qd._.context.create(model))

        assert.equal(dom.getChildren().length, 1, "Should have one child after update")
        assert.equal(dom.getChildren()[0].getProperty('nodeName'), "DIV", "Should have a div child")
        assert.equal(bindSpy.firstCall.args[0].raw, realModel, "Should have called with sub model")
    )
)