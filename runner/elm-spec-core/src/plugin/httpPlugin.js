const nise = require('nise')
const { report, line } = require('../report')

const fakeServerForGlobalContext = function(window) {
  const server = nise.fakeServer.create()
  server.xhr = nise.fakeXhr.fakeXMLHttpRequestFor(window).useFakeXMLHttpRequest()
  server.xhr.onCreate = (xhrObj) => {
    xhrObj.unsafeHeadersEnabled = function () {
        return !(server.unsafeHeadersEnabled === false);
    };
    server.addRequest(xhrObj);
  }
  server.respondImmediately = true
  return server
}

module.exports = class HttpPlugin {
  constructor(context) {
    this.server = fakeServerForGlobalContext(context.window)
  }

  reset() {
    this.server.reset()
  }

  handle(specMessage, out, next, abort) {
    switch (specMessage.name) {
      case "stub": {
        const stub = specMessage.body

        switch (stub.route.uri.type) {
          case "EXACT": {
            this.setupStub(stub, stub.route.uri.value)
            break
          }
          case "REGEXP": {
            try {
              this.setupStub(stub, new RegExp(stub.route.uri.value))
            } catch (err) {
              abort(report(
                line("Unable to parse regular expression for stubbed route", `/${stub.route.uri.value}/`)
              ))
            }
            break
          }
        }

        break
      }
      case "fetch-requests": {
        const route = specMessage.body
        let requests = []

        switch (route.uri.type) {
          case "EXACT": {
            requests = this.findRequests(route, (url) => {
              return url === route.uri.value
            })

            break
          }
          case "REGEXP": {
            try {
              const regex = new RegExp(route.uri.value)
              requests = this.findRequests(route, (url) => {
                return regex.test(url)
              })
            } catch (err) {
              abort(report(
                line("Unable to parse regular expression used to observe requests", `/${route.uri.value}/`)
              ))
              return
            }
          }
        }

        out({
          home: "_http",
          name: "requests",
          body: requests
        })

        break
      }
      default:
        console.log("Unknown Http message", specMessage)
    }
  }

  setupStub(stub, uriDescriptor) {
    this.server.respondWith(stub.route.method, uriDescriptor, (request) => {
      if (stub.shouldRespond) {
        if (stub.error === "network") {
          request.error()
        } else if (stub.error === "timeout") {
          request.eventListeners.timeout[1].listener()
          request.readyState = 4
        } else {
          request.respond(stub.status, stub.headers, stub.body)
        }
      } else {
        request.readyState = 4
      }
    })
  }

  findRequests(route, matchUrl) {
    return this.server.requests
      .filter(request => {
        if (request.method !== route.method) return false
        return matchUrl(request.url)
      })
      .map(buildRequest)
  }
}

const buildRequest = (request) => {
  return {
    url: request.url,
    headers: request.requestHeaders,
    body: request.requestBody || null
  }
}
