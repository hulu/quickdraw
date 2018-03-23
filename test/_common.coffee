vm = require("vm")
fs = require("fs")

COMPILED_PATH = "bin/quickdraw.js"

# load cached quickdraw script
rawSource = fs.readFileSync(COMPILED_PATH, "utf8")
cachedScript = vm.createScript(rawSource, COMPILED_PATH)

# setup test environment
global.chai = require('chai')
global.assert = require('chai').assert
global.expect = require('chai').expect
global.sinon = require('sinon')
global.jsdom = require('jsdom')

global.assertModuleBound = (moduleName) ->
    return ->
        assert.isNotNull(sandbox.qd._.state.binding.handlers[moduleName], "#{moduleName} handler should be bound")

global.createVirtualElement = (type = 'div') ->
    return sandbox.qd._.dom.virtualize(sandbox.document.createElement(type))

beforeEach(->
    # construct a sandbox to test in
    sandbox = global.sandbox = vm.createContext({
        Error : Error
        Array : Array
        console : console
        _$jscoverage : global._$jscoverage ? null
    })

    sandbox.setTimeout = sinon.spy(global.setTimeout)
    sandbox.clearTimeout = sinon.spy(global.clearTimeout)

    global.qdGetInitialize = (handleName) ->
        return sandbox.qd._.handlers.getInitialize(handleName)

    global.qdGetUpdate = (handleName) ->
        return sandbox.qd._.handlers.getUpdate(handleName)

    global.qdGetCleanup = (handleName) ->
        return sandbox.qd._.handlers.getCleanup(handleName)

    # construct a sandboxed quickdraw
    cachedScript.runInContext(sandbox)

    # refresh the dom
    dom = jsdom.jsdom()
    sandbox.window = dom.defaultView
    sandbox.document = sandbox.window.document
)