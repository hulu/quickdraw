describe("Quickdraw.Bindings.Visible", ->
    it("Handler is bound to visible keyword", assertModuleBound("visible"))

    it("Truth value uses default display", ->
        dom = createVirtualElement()
        dom.getRawNode().style.display = "inline-block"

        callback = qdGetUpdate("visible")

        callback(true, dom)

        assert.equal(dom.getStyle('display'), "", "Truth value sets display to default")
    )

    it("False value hides element", ->
        dom = createVirtualElement()
        dom.getRawNode().style.display = "inline-block"

        callback = qdGetUpdate("visible")

        callback(false, dom)

        assert.equal(dom.getStyle('display'), "none", "False value sets display to none")
    )
)