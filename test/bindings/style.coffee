describe("Quickdraw.Bindings.Style", ->
    it("Handler is bound to style keyword", assertModuleBound("style"))

    it("Sets the appropriate styles on the element", ->
        dom = createVirtualElement('div')
        callback = qdGetUpdate("style")
        callback({ color : "green", backgroundColor : "blue"}, dom)

        assert.equal(dom.getStyle('color'), "green", "Color property set")
        assert.equal(dom.getStyle('backgroundColor'), "blue", "Background property set")
    )
)