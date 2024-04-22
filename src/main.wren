/*
Preview pokemon models and animations in this editor
*/

import "graphics" for Canvas, Color, ImageData, Font
import "input" for Keyboard, Mouse
import "io" for FileSystem
import "pattern_animation" for LibraryPatternAnimationCollection
import "cell_animation" for CellAnimationResource
import "dome" for Process, Window, Log
import "controls" for AppColor, Button, AppFont

Log.level = "DEBUG"

class AnimationType {
  static walk { "A" }
  static attack { "B" }
  static damage { "C" }
  static sleep { "D" }
  static all { [ walk, attack, damage, sleep ] }
}

class AnimationDirection {
  static left { "N" }
  static right { "R" }
  static all { [ left, right ]}
}

class AnimationOrientation {
  static front { "F" }
  static back { "B" }
  static all { [ front, back ] }
}

class SpriteStore {
  static isSheetValid(sheet) {
    return sheet.width == 128 && sheet.height == 1024
  }

  construct new(sheet) {
    if (!SpriteStore.isSheetValid(sheet)) {
      Fiber.abort("Sprite sheet invalid")
    }
    _sheet = sheet
  }

  getSprite(x, y, flipX, scale) {
    return _sheet.transform({
      "srcX": x * 32, 
      "srcY": y * 32,
      "srcW": 32, 
      "srcH": 32,
      "scaleX": flipX ? -scale : scale,
      "scaleY": scale
    })
  }
}

class AnimationDisplay {
  construct new(drawX, drawY) {
    _updateCounter = -1
    _drawX = drawX
    _drawY = drawY
    _scale = 1
  }

  init(spriteStore, animationLibrary, type, direction, orientation, asymmetrical, longAttack) {
    _type = type
    _direction = direction
    _orientation = orientation
    _asymmetrical = asymmetrical
    _longAttack = longAttack
    _spriteStore = spriteStore
    _x = 0
    _y = 0
    _flipX = false
    var numTex = asymmetrical ? 3 : 4

    if (type == AnimationType.walk) {
      _x = _x + 0
      _y = _y + 0
    } else if (type == AnimationType.attack) {
      _x = _x + 1
      _y = _y - 12
    } else if (type == AnimationType.damage) {
      _x = _x + 2
      _y = _y + 0
    } else if (type == AnimationType.sleep) {
      _x = _x + 3
      if (!_asymmetrical) {
        _y = _y - 4
      }
    }

    if (orientation == AnimationOrientation.back) {
      if (type == AnimationType.attack) {
        _y = _y + (longAttack ? 8 : 4)
      }
    }

    if (direction == AnimationDirection.right) {
      //_y = _y + numTex * 2
      if (!asymmetrical) {
        _flipX = true
      }
    }

    _animation = animationLibrary.find(orientation, direction, type)
    if (_animation == null) {
      _animation = animationLibrary.find(orientation, AnimationDirection.left, type)
      _flipX = true
    }
  }

  getNumFromTex(texName) {
    return Num.fromString(texName[-2..-1])
  }

  update() {
    _updateCounter = _updateCounter + 1
    var keyFrame = _animation.sample("samplemap_MatLib", _updateCounter)
    _texIdx = getNumFromTex(keyFrame.texture)
    _currentSprite = _spriteStore.getSprite(_x, _y + _texIdx, _flipX, _scale)
  }

  draw(dt) {
    Canvas.draw(_currentSprite, _drawX, _drawY)
    Canvas.print("%(_orientation)%(_direction)_%(_type)", _drawX, _drawY - 10, Color.white)
  }
}



class State {
  update() {}
  draw(dt) {}
}

class FilesMissingState is State {
  construct new() {}
  draw(dt) {
    Canvas.print("Files Missing. Place an animation file, \nand a sprite sheet in the folder next\nto the application", 50, 50, AppColor.foreground)
  }
}

class PatternAnimationState is State {
  construct new(animationFile, spriteSheetFile) {
    Log.debug("Loading pattern animation state for files: anim='%(animationFile)', spriteSheet='%(spriteSheetFile)'")
    var animFileContent = FileSystem.load(animationFile)
    _animLibCollection = LibraryPatternAnimationCollection.new(animFileContent)
    _spriteStore = SpriteStore.new(ImageData.load(spriteSheetFile))
    _animationDisplays = []
    var y = 20
    for (typ in AnimationType.all) {
      var x = 10
      for (dir in AnimationDirection.all) {
        for (ori in AnimationOrientation.all) {
          var disp = AnimationDisplay.new(x, y)
          _animationDisplays.add(disp)
          disp.init(_spriteStore, _animLibCollection.library, typ, dir, ori, _animLibCollection.asymmetrical, _animLibCollection.longAttack)
          x = x + 50
        }
      }
      y = y + 50
    }
  }

  update() {
    for (disp in _animationDisplays) {
        disp.update()
      }
  }

  draw(dt) {
    for (disp in _animationDisplays) {
        disp.draw(dt)
      }
      Canvas.print("ASYMMETRICAL: %(_animLibCollection.asymmetrical)", 210, 10, Color.white)
      Canvas.print("LONG_ATTACK: %(_animLibCollection.longAttack)", 210, 25, Color.white)
  }
}

class AnimationPanel {
  construct new(cellAnimationResource) {
    _cellAnimationResource = cellAnimationResource
    _selection = -1
  }

  selection { _selection }

  update() {
    if (Keyboard["down"].justPressed) {
      if (_selection < _cellAnimationResource.animations.count - 1) {
        _selection = _selection + 1
      }
    } else if (Keyboard["up"].justPressed) {
      if (_selection > -1) {
        _selection = _selection - 1
      }
    }
  }

  draw(x, y) {
    drawAnimationsList(x + 15, y + 130)

    if (_selection != -1) {
      drawFramesList(x + 80, y + 130, _cellAnimationResource.animations[_selection])
    }
  }

  drawAnimationsList(x, y) {
    Canvas.print("ANIMATIONS", x, y, AppColor.domePurple)
    y = y + 10
    Canvas.print("all", x, y, AppColor.foreground)
    y = y + 10

    if (_cellAnimationResource.animations.count == 0) {
      Canvas.print("no animations", x, y, AppColor.gray)
    } else {
      for (i in 0..._cellAnimationResource.animations.count) {
        var anim = _cellAnimationResource.animations[i]
        Canvas.print(anim.name, x, y + i * 10, AppColor.foreground)
      }
    }
    Canvas.circle(x - 6, y + (_selection * 10) + 2, 2, AppColor.domePurple)
  }

  drawFramesList(x, y, animation) {
    Canvas.print("FRAMES", x, y, AppColor.domePurple)
    y = y + 10

    if (animation.frames.count == 0) {
      Canvas.print("no animations", x, y, AppColor.gray)
    } else {
      for (i in 0...animation.frames.count) {
        var frame = animation.frames[i]
        var fY = y + i * 10
        Canvas.print(frame.cluster, x, fY, AppColor.foreground)
        Canvas.print(frame.duration.toString, x + 40, fY, AppColor.foreground)
      }
    }
  }
}

class ClusterPanel {
  construct new(cellAnimationResource) {
    _cellAnimationResource = cellAnimationResource
    _selection = -1
  }

  selection { _selection }

  update() {
    if (Keyboard["down"].justPressed) {
      if (_selection < _cellAnimationResource.clusters.count - 1) {
        _selection = _selection + 1
      }
    } else if (Keyboard["up"].justPressed) {
      if (_selection > -1) {
        _selection = _selection - 1
      }
    }
  }

  draw(x, y) {
    drawClustersList(x + 15, y + 130)

    if (_selection != -1) {
      drawCellsList(x + 80, y + 130, _cellAnimationResource.clusters[_selection])
    }
  }

  drawClustersList(x, y) {
    Canvas.print("CLUSTERS", x, y, AppColor.domePurple)
    y = y + 10
    Canvas.print("all", x, y, AppColor.foreground)
    y = y + 10

    if (_cellAnimationResource.clusters.count == 0) {
      Canvas.print("no clusters", x, y, AppColor.gray)
    } else {
      for (i in 0..._cellAnimationResource.clusters.count) {
        var clust = _cellAnimationResource.clusters[i]
        Canvas.print(clust.name, x, y + i * 10, AppColor.foreground)
      }
    }
    Canvas.circle(x - 6, y + (_selection * 10) + 2, 2, AppColor.domePurple)
  }

  drawCellsList(x, y, cluster) {
    Canvas.print("CELLS", x, y, AppColor.domePurple)
    y = y + 10

    if (cluster.cells.count == 0) {
      Canvas.print("no cells", x, y, AppColor.gray)
    } else {
      for (i in 0...cluster.cells.count) {
        var cell = cluster.cells[i]
        var cY = y + i * 10
        Canvas.print("[%(cell.x),%(cell.y),%(cell.width),%(cell.height)]", x, cY, AppColor.foreground)
      }
    }
    
    
  }
}

class CellAnimationState is State {
  construct new(dir, animationFile) {
    _drawBackground = true
    _cellAnimationResource = CellAnimationResource.new(animationFile, dir)
    if (_cellAnimationResource.background != null) {
      var bgFile = dir + "/" + _cellAnimationResource.background
      _background = ImageData.load(bgFile)
    }

    _animationPanel = AnimationPanel.new(_cellAnimationResource)
    _clusterPanel = ClusterPanel.new(_cellAnimationResource)
    _currentPanel = _animationPanel
  }

  update() {
    _cellAnimationResource.update()
    if (Keyboard["b"].justPressed) {
      _drawBackground = !_drawBackground
    }
    if (Keyboard["p"].justPressed) {
      if (_currentPanel == _animationPanel) {
        _currentPanel = _clusterPanel
      } else {
        _currentPanel = _animationPanel
      }
    }
    _currentPanel.update()
  }

  draw(dt) {
    var x = 0
    var y = 0
    if (_background != null && _drawBackground) {
      Canvas.draw(_background, x, y)
    }

    if (_currentPanel.selection == -1) {
      _cellAnimationResource.draw(x, y)
    } else if (_currentPanel == _animationPanel) {
      _cellAnimationResource.drawAnimation(x, y, _animationPanel.selection)
    } else {
      _cellAnimationResource.clusters[_clusterPanel.selection].draw(x, y)
    }

    _currentPanel.draw(x, y)
  }
}

class Main {
  construct new() { }
  
  init() {
    Window.title = "RL-Animate v1.0"
    AppFont.load()
    
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