import Flutter
import SVGKit
import UIKit
import XCTest


@testable import mobile_app_privacy

// This demonstrates a simple unit test of the Swift portion of this plugin's implementation.
//
// See https://developer.apple.com/documentation/xctest for more information about using XCTest.

class RunnerTests: XCTestCase {

  func testSVGIconRenders() throws {
    let data = Data("""
      <svg xmlns="http://www.w3.org/2000/svg" width="10" height="10" viewBox="0 0 10 10">
        <rect width="10" height="10" fill="red"/>
      </svg>
      """.utf8)
    let svg = try XCTUnwrap(SVGKImage(data: data))
    let image = try XCTUnwrap(svg.uiImage)

    XCTAssertEqual(image.size, CGSize(width: 10, height: 10))
  }

  func testGetPlatformVersion() {
    let plugin = MobileAppPrivacyPlugin()

    let call = FlutterMethodCall(methodName: "getPlatformVersion", arguments: [])

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      XCTAssertEqual(result as! String, "iOS " + UIDevice.current.systemVersion)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

}
