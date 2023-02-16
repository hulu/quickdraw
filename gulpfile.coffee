# basic script includes
minimist  = require("minimist")
fs        = require("fs")

# get npm and the internal logger it is using
npm       = require("npm")
npmlog    = require("npm/node_modules/npmlog")

# gulp related includes
gulp      = require("gulp")
coffee    = require("gulp-coffee")
coffeeCov = require("gulp-coffee-coverage")
concat    = require("gulp-concat")
del       = require("del")
header    = require("gulp-header")
mocha     = require("gulp-mocha")
prompt    = require("gulp-prompt")
rename    = require("gulp-rename")
shell     = require("gulp-shell")
uglify    = require("gulp-uglify")

args = minimist(process.argv.slice(2), {
    string  : ["dir", "type", "channel"]
    boolean : ["debug"]
    default : {
        channel : "latest"
        type : "patch"
        debug : false
    }
})

# Check that any arguments given are valid
# Type argument
unless args.type in ["major", "minor", "patch", "prerelease"]
    console.error("Invalid type given, must be either 'major', 'minor', 'patch', or 'prerelease'")
    process.exit(1)

if args.type is "prerelease"
    args.channel = "rc"

# check the directory given exists
if args.dir?
    stats = fs.statSync(args.dir)
    unless stats.isDirectory()
        console.error("Given path is not a directory")
        process.exit(1)

PATHS = {
    coffeeSource : ["src/quickdraw.coffee", "src/base/**.coffee", "src/bindings/**.coffee"]
    tests : ["test/**/*.coffee"]
    typeDeclaration: "src/quickdraw.d.ts"
}

# Files
CONCAT_FILE = "quickdraw.coffee"
COMPILED_FILE = "quickdraw.js"
MINIFIED_FILE = "quickdraw.min.js"

# Folders
BUILD_FOLDER = "bin"
LCOV_FILE = "#{BUILD_FOLDER}/coverage.lcov"
XUNIT_FILE = "#{BUILD_FOLDER}/coverage.xml"
COVERAGE_FOLDER = "#{BUILD_FOLDER}/coverage"
RELEASE_FOLDER = "lib"
CLEAN_UP = [BUILD_FOLDER, RELEASE_FOLDER, COVERAGE_FOLDER, LCOV_FILE]

getHeaderAddition = (debug = false) ->
    pkg = require("./package.json")

    if debug
        pkg.version = "custom build based on source of #{pkg.version}"
    else
        pkg.version = "v#{pkg.version}"

    content = [
        "/**"
        " * <%= name %> - <%= description %>"
        " * @version <%= version %>"
        " * @channel <%= channel %>"
        " */"
        ""
    ]
    return header(content.join("\n"), {
        name        : pkg.name
        description : pkg.description
        version     : pkg.version
        channel     : args.channel
    })

gulp.task("clean", ->
    # return the promise result to signal async
    return del(CLEAN_UP)
)

gulp.task("compile", gulp.series("clean", ->
    source = PATHS.coffeeSource
    if args.debug
        source.push("src/debug/**.coffee")
    return gulp.src(source)
        .pipe(concat(CONCAT_FILE))
        .pipe(coffee())
        .pipe(rename(COMPILED_FILE))
        .pipe(gulp.dest(BUILD_FOLDER))
))

gulp.task("minify", gulp.series("compile", ->
    return gulp.src("#{BUILD_FOLDER}/#{COMPILED_FILE}")
        .pipe(uglify())
        .pipe(rename(MINIFIED_FILE))
        .pipe(gulp.dest(BUILD_FOLDER))
))

gulp.task("compile:coverage", gulp.series("clean", ->
    return gulp.src(PATHS.coffeeSource)
        .pipe(coffeeCov({
            bare : true
        }))
        .pipe(concat(COMPILED_FILE))
        .pipe(gulp.dest(BUILD_FOLDER))
))

gulp.task("test", gulp.series("clean", "compile", ->
    return gulp.src(PATHS.tests, { read : false })
        .pipe(mocha({
            reporter : "spec"
        }))
))

gulp.task("test:coverage", gulp.series("clean", "compile:coverage", ->
    return gulp.src(PATHS.tests, { read : false })
        .pipe(mocha({
            reporter : "mocha-multi"
            reporterOptions : {
                spec : {
                    stdout : "-"
                }
                "mocha-lcov-reporter" : {
                    stdout : LCOV_FILE
                }
                "xunit" : {
                    stdout : XUNIT_FILE
                }
            }
        }))
))

gulp.task("coverage", gulp.series("test:coverage", shell.task([
    "sleep 1 && genhtml #{LCOV_FILE} -o #{COVERAGE_FOLDER}"
])))

gulp.task("release:organize", gulp.series("test", "minify", ->
    return gulp.src(["#{BUILD_FOLDER}/#{COMPILED_FILE}", "#{BUILD_FOLDER}/#{MINIFIED_FILE}", PATHS.typeDeclaration])
        .pipe(getHeaderAddition())
        .pipe(gulp.dest(RELEASE_FOLDER))
        .pipe(prompt.confirm({
            message: "All tests have passed, do you want to publish this to npm?",
            default: false
        }))
))

gulp.task("release", gulp.series("release:organize", (cb) ->
    pkg = require("./package.json")
    npm.load(pkg, (err) ->
        return cb(err) if err

        # disable the progress bar as it doesn't work well with gulp
        npmlog.disableProgress()

        # set the tag to the appropriate channel
        npm.config.set("tag", args.channel)

        # publish the repository
        npm.commands.publish(cb)
    )
))

gulp.task("install", gulp.series("clean", "compile", ->
    unless args.dir?
        console.error("No directory specified for installation, use --dir flag")
        process.exit(1)

    # set default out if none defined
    return gulp.src(["#{BUILD_FOLDER}/#{COMPILED_FILE}", PATHS.typeDeclaration])
        .pipe(getHeaderAddition(true))
        .pipe(gulp.dest(args.dir))
))

gulp.task("default", gulp.series("clean", "compile"))
