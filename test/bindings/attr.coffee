describe('Quickdraw.Bindings.Attr', ->
    it('Handler is bound to attr keyword', assertModuleBound('attr'))

    it('Sets a single attribute', ->
        dom = createVirtualElement('div')
        callback = qdGetUpdate('attr')
        callback({ title : 'cats' }, dom)

        assert.equal(dom.getAttribute('title'), 'cats', 'Attribute properly set')
    )

    it('Sets multiple attributes', ->
        dom = createVirtualElement('div')
        callback = qdGetUpdate('attr')
        callback({
            title : 'cats'
            href : 'google.com'
        }, dom)

        assert.equal(dom.getAttribute('title'), 'cats', 'Attribute properly set')
        assert.equal(dom.getAttribute('href'), 'google.com', 'Other property set')
    )

    it('If attribute is null, removed from ', ->
        dom = createVirtualElement('div')
        dom.setAttribute('cats', 'yes')
        callback = qdGetUpdate('attr')
        callback({
            cats : null
        }, dom)

        assert.isFalse(dom.hasAttribute('cats'), "Should not have cats attribute anymore")
    )

    it('On cleanup any added attributes are removed', ->
        dom = createVirtualElement('div')
        dom.setAttribute('cats', 'yes')
        callback = qdGetUpdate('attr')
        callback({
            dogs : "yes"
        }, dom)

        cleanup = qdGetCleanup('attr')
        cleanup(dom)

        assert.isFalse(dom.hasAttribute('dogs'), "Should not have attribute added via binding")
        assert.isTrue(dom.hasAttribute('cats'), "Should have attribute that was not from bindings")
    )
)