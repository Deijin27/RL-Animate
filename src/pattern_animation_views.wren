import "graphics" for Canvas, Color, ImageData
import "input" for Keyboard, Mouse
import "io" for FileSystem
import "pattern_animation" for LibraryPatternAnimationCollection
import "dome" for Process, Window, Log
import "controls" for AppColor, Button, AppFont, ListView
import "cell_animation_views" for CellAnimationState

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

class PatternAnimationState {
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