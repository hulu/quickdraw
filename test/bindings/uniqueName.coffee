describe("Quickdraw.Bindings.UniqueName", ->
    it("Handler is bound to html keyword", assertModuleBound("uniqueName"))

    it("Dom element given unique name", ->
        dom = createVirtualElement()

        callback = qdGetInitialize("uniqueName")

        callback(true, dom)

        assert.isNotNull(dom.getAttribute("name"), "HTML element should have a unique name now")
    )
)