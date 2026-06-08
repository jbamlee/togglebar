import Foundation
import ToggleKit

// Thin CLI over ToggleKit. This is also the gateway every other surface
// (Raycast, Shortcuts, global hotkeys) calls into.

let arguments = Array(CommandLine.arguments.dropFirst())

func printUsage() {
    print("""
    togglebar — toggle hub CLI

    usage:
      togglebar list            list every toggle with its current state
      togglebar status <id>     print "on" or "off"
      togglebar on <id>         turn on
      togglebar off <id>        turn off
      togglebar toggle <id>     flip
      togglebar dashboard       open the dashboard window
    """)
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

guard let command = arguments.first else { printUsage(); exit(0) }

switch command {
case "list":
    for toggle in ToggleEngine.loadConfig().toggles {
        let state = ToggleEngine.isOn(toggle) ? "on " : "off"
        print("[\(state)] \(toggle.id)\t\(toggle.title)")
    }

case "dashboard":
    // Routes to the running app (or cold-launches it) via the URL scheme.
    ToggleEngine.shell("open 'togglebar://dashboard'")

case "status", "on", "off", "toggle":
    guard arguments.count >= 2 else { fail("missing toggle id") }
    guard let toggle = ToggleEngine.find(arguments[1]) else { fail("unknown toggle id: \(arguments[1])") }
    switch command {
    case "status": print(ToggleEngine.isOn(toggle) ? "on" : "off")
    case "on":     ToggleEngine.setState(toggle, on: true)
    case "off":    ToggleEngine.setState(toggle, on: false)
    case "toggle": ToggleEngine.toggle(toggle)
    default:       break
    }

case "-h", "--help", "help":
    printUsage()

default:
    fail("unknown command: \(command)")
}
