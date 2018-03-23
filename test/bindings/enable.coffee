describe("Quickdraw.Bindings.Enable", ->
    it("Handler is bound to enable keyword", assertModuleBound("enable"))

    it("Element is enabled when value is true", ->
        dom = createVirtualElement('input')

        callback = qdGetUpdate("enable")

        callback(true, dom)

        assert.isFalse(dom.getProperty('disabled'), "Dom is enabled")
    )

    it("Element is disabled when value is false", ->
        dom = createVirtualElement('input')

        callback = qdGetUpdate("enable")

        callback(false, dom)

        assert.isTrue(dom.getProperty('disabled'), "Dom is disabled")
    )
)