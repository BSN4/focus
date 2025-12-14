//
//  main.swift
//  Focus
//
//  A lightweight macOS menu bar app that enforces single-app focus.
//  Copyright (c) 2024 Bader <BNS4@pm.me>
//
//  MIT License
//

import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
