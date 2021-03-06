const chai = require('chai')
const expect = chai.expect
const { ElmSpecReporter } = require('../lib/elmSpecReporter')

describe("elm-spec reporter", () => {
  let subject
  let lines

  beforeEach(() => {
    lines = []

    subject = new ElmSpecReporter((self) => {
      self.write = (line) => lines.push(line)
    })
  })

  describe("when there are no rejected specs", () => {
    beforeEach(() => {
      subject.onRunStart()
      subject.onRunComplete(null, {
        success: 3,
        failed: 0
      })
    })

    it("prints only the accepted count", () => {
      expectToContain(lines, [
        "Accepted: 3"
      ])
    })
  })

  describe("when there are rejected specs", () => {
    beforeEach(() => {
      subject.onRunStart()
      subject.specFailure(null, failureResult())
      subject.specFailure(null, failureResultTwo())
      subject.onRunComplete(null, {
        success: 3,
        failed: 2
      })
    })

    it("prints the count and the rejection reports", () => {
      expectToContain(lines, [
        "Accepted: 3",
        "Rejected: 2",
        "Failed to satisfy spec:",
        "Describing: Something",
        "Scenario: Something happens",
        "When some event occurs",
        "it failed to do something",
        "Expected",
        "7",
        "to equal",
        "5",
        "Failed to satisfy spec:",
        "Describing: Another Thing",
        "Scenario: Something else happens",
        "When some other event occurs",
        "it failed to do another thing",
        "Expected",
        "something",
        "with",
        "multiple lines",
        "to be",
        "something else",
        "and some final",
        "statement",
        "with multiple",
        "lines"
      ])
    })
  })

  describe("when there is an elm-spec error", () => {
    beforeEach(() => {
      subject.onRunStart()
      subject.onBrowserError(null, {
        message: [
          { statement: "Some error occurred with",
            detail: "something"
          },
          { statement: "some final statement",
            detail: null
          }
        ]
      })
    })

    it("prints the error", () => {
      expectToContain(lines, [
        "Error running spec suite!",
        "Some error occurred with",
        "something",
        "some final statement"
      ])
    })
  })

  describe("when there is some uncaught browser error", () => {
    beforeEach(() => {
      subject.onRunStart()
      subject.onBrowserError(null, "There was an error initializing Elm, like two ports with the same name!")
      subject.onRunComplete(null, {
        success: 0,
        failed: 0
      })
    })

    it("prints the error", () => {
      expectToContain(lines, [
        "There was an error initializing Elm, like two ports with the same name!"
      ])
    })
  })
})

const expectToContain = (actualLines, expectedLines) => {
  const actualWithoutBlanks = actualLines.filter(line => line !== "\n" && line !== "\n\n" && line !== '\u001b[31mx\u001b[39m')
  expectedLines.forEach((expectedLine, index) => {
    expect(index, `Expected at least ${index + 1} actual lines, but there are only ${actualWithoutBlanks.length}`).to.be.lessThan(actualWithoutBlanks.length)
    expect(actualWithoutBlanks[index]).to.contain(expectedLine)
  })
  expect(expectedLines.length, "Number of actual lines does not equal number of expected lines").to.equal(actualWithoutBlanks.length)
}

const failureResult = () => {
  return {
    id: "obs-1",
    description: "it failed to do something",
    suite: [
      "Describing: Something",
      "Scenario: Something happens",
      "When some event occurs"
    ],
    log: [
      { statement: "Expected",
        detail: "7"
      },
      { statement: "to equal",
        detail: "5"
      }
    ],
    success: false,
    skipped: false
  }
}

const failureResultTwo = () => {
  return {
    id: "obs-1",
    description: "it failed to do another thing",
    suite: [
      "Describing: Another Thing",
      "Scenario: Something else happens",
      "When some other event occurs"
    ],
    log: [
      { statement: "Expected",
        detail: "something\nwith\nmultiple lines"
      },
      { statement: "to be",
        detail: "something else"
      },
      { statement: "and some final\nstatement\nwith multiple\nlines",
        detail: null
      }
    ],
    success: false,
    skipped: false
  }
}