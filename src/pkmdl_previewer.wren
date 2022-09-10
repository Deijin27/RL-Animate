/*
Preview pokemon models and animations in this editor
*/

import "graphics" for Canvas, Color, ImageData
import "input" for Keyboard
import "io" for FileSystem
import "sprite_store" for SpriteStore
import "pattern_animation" for LibraryPatternAnimationCollection

class State {
  startupScreen { 0 }
  previewer { 1 }
}

class Main {
  construct new() { }
  
  init() {
    // load files
    var surroundingFiles = FileSystem.listFiles("")
    for (f in surroundingFiles) {
      if (f.endsWith(".png")) {
        _spriteSheetFile = f
      } else if (f.endsWith(".xml")) {
        _animationFile = f
      }
    }
    
    reloadData()
  }
  
  reloadData() {
    //loadAnimationFile(_animationFile)
    loadSpriteSheetFile(_spriteSheetFile)
    _currentSprite = _spriteStore.getSprite(5, 5, false, 1)
  }
  
  update() {
  }
  
  draw(dt) {
    Canvas.cls(Color.black)
    Canvas.draw(_currentSprite, 0, 0)
  }

  loadAnimationFile(animationFile) {
    var text = FileSystem.read(animationFile)
    _animCollection = LibraryPatternAnimationCollection.new(text)
  }

  loadSpriteSheetFile(spriteSheetFile) {
    var sheet = ImageData.loadFromFile(spriteSheetFile)
    _spriteStore = SpriteStore.new(sheet)
  }
}

var Game = Main.new()