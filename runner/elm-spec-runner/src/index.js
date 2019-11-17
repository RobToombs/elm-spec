const {Command, flags} = require('@oclif/command')
const Compiler = require('elm-spec-core/src/compiler')
const Reporter = require('./consoleReporter')
const JsdomContext = require('./jsdomContext')
const SuiteRunner = require('elm-spec-core')
const commandExists = require('command-exists').sync
const glob = require("glob")
const process = require('process')

class ElmSpecRunnerCommand extends Command {
  async run() {
    const {flags} = this.parse(ElmSpecRunnerCommand)
    
    const elmPath = flags.elm || 'elm'
    if (!commandExists(elmPath)) {
      if (flags.elm) {
        this.error(`No elm executable found at: ${flags.elm}`)
      } else {
        this.error('No elm executable found in the current path')
      }
    }

    const specPath = flags.specs
    if (glob.sync(specPath).length == 0) {
      this.error(`No spec modules found matching: ${specPath}`)
    }    

    const tags = flags.tag || []

    this.runSpecs({
      specPath,
      elmPath,
      tags,
      runnerOptions: {
        endOnFailure: flags.endOnFailure,
        timeout: 500
      }
    })
  }

  runSpecs(options) {
    const compiler = new Compiler(options)

    const context = new JsdomContext(compiler, options.tags)
    const reporter = new Reporter((c) => process.stdout.write(c), this.log)

    const runner = new SuiteRunner(context, reporter, options.runnerOptions)
    runner.runAll()
  }
}

ElmSpecRunnerCommand.description = `Run Elm-Spec specs from the command line
...
Extra documentation goes here
`

ElmSpecRunnerCommand.flags = {
  // add --version flag to show CLI version
  version: flags.version({char: 'v'}),
  // add --help flag to show CLI version
  help: flags.help({char: 'h'}),
  elm: flags.string({char: 'e', description: 'path to elm'}),
  specs: flags.string({char: 's', description: 'glob for spec modules', default: './specs/**/*Spec.elm'}),
  tag: flags.string({char: 't', description: 'execute scenarios with this tag only', multiple: true}),
  endOnFailure: flags.boolean({char: 'f', description: 'end on first failure', default: false})
}

module.exports = ElmSpecRunnerCommand
