describe("Quickdraw.Internal.Strings", ->
    describe("appendWithDelimiter(string, item, delimiter)", ->
        it("Non-empty string has delimiter and item added", ->
            string = "hello"
            delimiter = " "
            item = "world!"
            combined = sandbox.qd._.strings.appendWithDelimiter(string, item, delimiter)
            assert.equal(combined, string + delimiter + item, "Strings are equal")
        )

        it("Empty string does not add delimiter", ->
            combined = sandbox.qd._.strings.appendWithDelimiter("", "alone", " ")
            assert.equal(combined, "alone", "Strings are equal")
        )

        it("Delimiter at end is not repeated", ->
            string = "hello "
            delimiter = " "
            item = "world!"
            combined = sandbox.qd._.strings.appendWithDelimiter(string, item, delimiter)
            assert.equal(combined, string + item, "Strings are equal")
        )
    )

    describe("Tokenizer", ->
        it("Tokenizer properly splits on delimiter singles", ->
            words = ["hello", "to", "the", "world"]
            string = words.join(" ")
            delimiter = " "
            tokenizer = new sandbox.qd._.strings.tokenizer(string, delimiter)
            pieces = tokenizer.toArray()
            assert.equal(pieces.length, words.length, "All pieces found")
            for word, i in words
                assert.equal(pieces[i], word, "Pieces found in correct order")
        )

        it("Tokenizer splits with arbitrary delimiter repetition", ->
            words = ["hello", "to", "the", "world"]
            string = "#{words[0]}     #{words[1]} #{words[2]} #{words[3]}"
            delimiter = " "
            tokenizer = new sandbox.qd._.strings.tokenizer(string, delimiter)
            pieces = tokenizer.toArray()
            assert.equal(pieces.length, words.length, "All pieces found")
            for word, i in words
                assert.equal(pieces[i], word, "Pieces found in correct order")
        )

        it("Tokenizer with string that doesnt contain delimiter returns whole string", ->
            string = "helloworld"
            delimiter = " "
            tokenizer = new sandbox.qd._.strings.tokenizer(string, delimiter)
            assert.equal(tokenizer.nextToken(), string, "Only thing returned is all")
            assert.isNull(tokenizer.nextToken(), "Nothing else left")
        )

        it("Tokenizer returns null for null string", ->
            tokenizer = new sandbox.qd._.strings.tokenizer(null, " ")
            assert.isNull(tokenizer.nextToken(), "Null string is null")
        )

        it("Tokenizer returns null after all pieces found", ->
            string = "hello world"
            delimiter = " "
            tokenizer = new sandbox.qd._.strings.tokenizer(string, delimiter)
            assert.equal(tokenizer.nextToken(), "hello", "First word correct")
            assert.equal(tokenizer.nextToken(), "world", "Second word correct")
            assert.isNull(tokenizer.nextToken(), "Everything else null")
        )
    )
)