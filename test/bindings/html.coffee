describe("Quickdraw.Bindings.Html", ->
    it("Handler is bound to html keyword", assertModuleBound("html"))

    it("HTML should be parsed and added", ->
        dom = createVirtualElement('div')

        callback = qdGetUpdate("html")
        setHTML = "<div>New Elements</div>"

        callback(setHTML, dom)

        assert.equal(dom.getProperty('innerHTML'), setHTML, "HTML should be directly set")
    )

    it("Old elements are cleared when html added", ->
        dom = createVirtualElement('div')
        dom.getRawNode().innerHTML = "<span>Old Elements are the best</span>"

        callback = qdGetUpdate("html")
        setHTML = "<div>New Elements</div>"

        callback(setHTML, dom)

        assert.equal(dom.getProperty('innerHTML'), setHTML, "HTML should be updated to given")
    )
)
