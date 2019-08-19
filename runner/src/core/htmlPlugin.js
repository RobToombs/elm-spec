
module.exports = class HtmlPlugin {
  constructor(window, clock) {
    this.window = window
    this.document = window.document
    this.clock = clock
  }

  handle(specMessage, out, abort) {
    switch (specMessage.name) {
      case "select":
        const selector = specMessage.body.selector
        const element = this.document.querySelector(selector)
        out({
          home: "_html",
          name: "selected",
          body: {
            tag: element.tagName,
            children: [
              { text: element.textContent }
            ]
          }
        })
        break
      case "target": {
        const element = this.document.querySelector(specMessage.body)
        if (element == null) {
          abort(`No match for selector: ${specMessage.body}`)
        } else {
          out(specMessage)
        }
        break
      }
      case "click": {
        const element = this.document.querySelector(specMessage.body.selector)
        element.click()
        break
      }
      case "input": {
        const element = this.document.querySelector(specMessage.body.selector)
        element.value = specMessage.body.text
        const event = this.window.eval("new Event('input', {bubbles: true, cancelable: true})")
        element.dispatchEvent(event)
        break
      }
      default:
        console.log("Unknown message:", specMessage)
        break
    }
  }

  onStepComplete() {
    this.clock.runToFrame()
  }
}