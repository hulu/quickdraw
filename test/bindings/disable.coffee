describe("Quickdraw.Bindings.Disable", ->
    it("Handler is bound to disable keyword", assertModuleBound("disable"))

    it("Element is disabled when value is true", ->
        dom = createVirtualElement('input')

        callback = qdGetUpdate("disable")

        callback(true, dom)

        assert.isTrue(dom.getProperty('disabled'), "Dom is disabled")
    )

    it("Element is enabled when value is false", ->
        dom = createVirtualElement('input')

        callback = qdGetUpdate("disable")

        callback(false, dom)

        assert.isFalse(dom.getProperty('disabled'), "Dom is enabled")
    )
)