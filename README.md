# ReelFlow

[English](README.md) | [简体中文](README.zh-CN.md)

ReelFlow is a native macOS app for turning photo sets into polished slideshow videos with fast preview, reliable export, and lightweight creative controls.

It is designed for photographers and creators who want a focused tool instead of a full nonlinear editor: import photos, preview the result, add music, adjust pacing, and export an MP4 that feels intentional instead of templated.

![ReelFlow screenshot](assets/readme/ReelFlow.jpg)

Main workspace for importing photos, adjusting slideshow settings, previewing output, and exporting MP4.

## What It Helps You Do

ReelFlow is for the common job that many editing tools handle badly: turning a set of still images into a clean, presentable video without building a full edit from scratch.

Typical use cases:

- create a photo slideshow for delivery, presentation, or social sharing
- turn a shoot, trip, or portfolio set into a motion reel
- add simple music and timing without learning a heavy editor
- export quickly from a Mac-native workflow

## Why People Use ReelFlow

Most video editors are too heavy for simple photo-to-video work, and many slideshow tools are too limited or too fragile.

ReelFlow focuses on a narrower problem:

- import photos and get to a usable result quickly
- keep preview and export behavior aligned
- surface risky assets before a long export fails
- make the main path obvious, even for first-time users
- stay focused on slideshow creation rather than full video editing

## Why It Feels Better Than a Generic Slideshow Tool

- native macOS interface instead of a browser wrapper
- faster path from import to export
- more control than one-click slideshow templates
- more approachable than a full timeline editor
- clearer validation, recovery, and export diagnostics

## Core Workflow

1. Import a photo set.
2. Adjust timing, transition, layout, and visual style.
3. Preview the result.
4. Add a background track if needed.
5. Export an MP4.

## Product Highlights

### Fast Preview, Predictable Export

- single-frame and timeline preview
- preview uses the same core settings as export
- export behavior is designed to stay predictable

### Photo-First Controls

- drag-and-drop photo import
- mixed landscape and portrait support
- orientation strategy controls
- configurable frame margin, border, and background styling

### Audio

- import a single background track
- preview audio along the timeline
- export video with synchronized audio

### Motion and Timing

- slideshow duration controls
- transition duration controls
- fade in and fade out toggles
- Ken Burns-style motion support in the render pipeline

### Reliability Before Rendering

- preflight checks before export
- inline validation feedback
- failure summaries and retry paths
- export diagnostics bundle for support and debugging

## Free and Pro

- Free: up to a limited number of imported photos, with a lightweight ReelFlow mark on preview and export
- Pro: unlimited photo imports and mark-free exports

## Requirements

- macOS `14.6` or later

## Availability

ReelFlow is an open-source product, and the official app may also be distributed commercially, including through the Mac App Store.

This repository is the best place to understand the product, follow development, and build it from source.

## For Developers

### Built With

- Swift
- SwiftUI
- AVFoundation
- Core Image
- native macOS app architecture

### Run From Source

```bash
git clone git@github.com:aruis/ReelFlow.git
cd ReelFlow
open ReelFlow.xcodeproj
```

Then build and run the `ReelFlow` scheme in Xcode.

### Command-Line Build

```bash
xcodebuild -project ReelFlow.xcodeproj -scheme ReelFlow build
```

## Testing

Useful local commands:

- `./scripts/test-non-ui.sh`
- `./scripts/test-audio-regression.sh`
- `./scripts/test-ui-smoke.sh`
- `./scripts/test-ci-gate.sh`
- `./scripts/release-gate.sh`

## Project Structure

- [`ReelFlow`](/Users/liurui/develop/workspace-xcode/ReelFlow/ReelFlow): app source
- [`ReelFlowTests`](/Users/liurui/develop/workspace-xcode/ReelFlow/ReelFlowTests): unit and integration tests
- [`ReelFlowUITests`](/Users/liurui/develop/workspace-xcode/ReelFlow/ReelFlowUITests): UI smoke coverage
- [`scripts`](/Users/liurui/develop/workspace-xcode/ReelFlow/scripts): local test and release scripts
- [`Docs`](/Users/liurui/develop/workspace-xcode/ReelFlow/Docs): deeper product, release, and engineering documents

## Roadmap

Product priorities:

- keep preview and export highly predictable
- improve first-time success on real photo sets
- continue polishing export recovery and diagnostics
- ship a production-ready distribution flow for broader release

Longer-term directions:

- stronger reusable presets and templates
- broader slideshow style coverage
- tighter release packaging and distribution workflow

## Contributing

Issues and pull requests are welcome, especially for:

- export reliability
- preview/export consistency
- accessibility and usability improvements
- test coverage around real-world failure paths

Before opening a large change, it is better to start with an issue so scope and product direction stay aligned.

## License

This project is licensed under the GNU GPLv3.

See [LICENSE](/Users/liurui/develop/workspace-xcode/ReelFlow/LICENSE) for the full text.
