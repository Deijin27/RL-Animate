/*
Preview pokemon models and animations in this editor
*/

import "graphics" for Canvas, Color, ImageData
import "input" for Keyboard, Mouse
import "io" for FileSystem
import "pattern_animation" for LibraryPatternAnimationCollection
import "dome" for Process, Window, Log
import "controls" for AppColor, Button, AppFont, Hotkey
import "cell_animation_views" for CellAnimationState
import "pattern_animation_views" for PatternAnimationState

Log.level = "DEBUG"

class FilesMissingState {
  construct new() {}
  draw(dt) {
    Canvas.print("Files Missing. Place an animation file, \nand a sprite sheet in the folder next\nto the application", 50, 50, AppColor.foreground)
  }
  update() {}
}


class Main {
  construct new() { }
  
  init() {
    Window.title = "RL-Animate v1.0"
    AppFont.load()

    Hotkey.register("up", "up")
    Hotkey.register("down", "down")
    Hotkey.register("left", "left")
    Hotkey.register("right", "right")
    Hotkey.register("toggleBackground", "b")
    Hotkey.register("switchMode", "tab")
    Hotkey.register("navigateForward", "return")
    Hotkey.register("navigateBack", "escape")
    Hotkey.register("toggleAllAnimations", "a")
    Hotkey.register("delete", "delete")
    
    _reloadButton = Button.new(10, 220, "RELOAD")
    reload()
  }

  reload() {
    _state = loadPatternAnimation() || loadCellAnimation() || FilesMissingState.new()
  }

  loadPatternAnimation() {
    var animationFile = null
    var spriteSheetFile = null

    var surroundingFiles = FileSystem.listFiles("")
    for (f in surroundingFiles) {
      if (f.endsWith(".png")) {
        spriteSheetFile = f
      } else if (f.endsWith(".xml")) {
        animationFile = f
      }
    }

    if (spriteSheetFile != null && animationFile != null) {
      return PatternAnimationState.new(animationFile, spriteSheetFile)
    }
    return null
  }

  loadCellAnimation() {
    var surroundingDirs = FileSystem.listDirectories("")
    for (d in surroundingDirs) {
      var surroundingFiles = FileSystem.listFiles(d)
      for (f in surroundingFiles) {
        if (f.endsWith(".xml")) {
          return CellAnimationState.new(d, d + "/" + f)
        }
      }
    }
    return null
  }

  update() {
    _reloadButton.update()
    if (_reloadButton.justPressed) {
      reload()
    }
    _state.update()
  }

  draw(dt) {
    Canvas.cls(AppColor.background)
    _reloadButton.draw(dt)
    _state.draw(dt)
    //Canvas.print("FPS: %(Window.fps)", 0, 0, Color.white)
  }
}

var Game = Main.new()