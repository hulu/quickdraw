describe("Quickdraw.Bindings.Text", ->
    it("Handler is bound to text keyword", assertModuleBound("text"))

    it("Text should be set to node text value", ->
        dom = createVirtualElement('div')

        callback = qdGetUpdate("text")
        setText = "Hello world!"

        callback(setText, dom)

        assert.equal(dom.getProperty('textContent'), setText, "Text value should be updated")
    )

    it("All content should be cleared when text entered", ->
        dom = createVirtualElement('div')
        dom.getRawNode().innerHTML = "<div>im an inner div</div><div>so am i</div>"

        callback = qdGetUpdate("text")
        setText = "No more divs"

        callback(setText, dom)

        assert.equal(dom.getProperty('textContent'), setText, "Text value should be updated")
    )

    it("HTML content should be escaped and not parsed", ->
        dom = createVirtualElement('div')

        callback = qdGetUpdate("text")
        setText = "<div>Injection Attack</div>"
        callback(setText, dom)

        assert.equal(dom.getProperty('textContent'), setText, "Content is unchanged")
    )
)