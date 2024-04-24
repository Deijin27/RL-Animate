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
import "math" for Math

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

class Hotkey {
  construct new(name, key) {
    _name = name
    _key = key
  }

  name { _name }
  key { _key }

  justPressed {
    return Keyboard[key].justPressed
  }

  static [name] {
    var hk = __hotkeys[name]
    if (hk == null) {
      Fiber.abort("No hotkey found of name %(name)")
    }
    return hk
  }

  static register(name, key) {
    __hotkeys[name] = Hotkey.new(name, key)
  }

  static init_() {
    __hotkeys = {}
  }
}
Hotkey.init_()

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

class Selector {
  construct new(min, max, init) {
    _selection = init
    _min = min
    _max = max
  }

  selection { _selection }

  update() {
    
  }
}

class ListView {
  construct new(title, items, drawItemFn) {
    _title = title
    _items = items
    _selectedIndex = 0
    _isFocused = true
    _drawItemFn = drawItemFn
    _visibleItemCapacity = 7
    _scrollPosition = 0
  }

  title { _title }
  isFocused { _isFocused }
  isFocused=(value) { _isFocused = value }
  selectedIndex { _selectedIndex }
  selectedItem { _items.count > 0 ? _items[_selectedIndex] : null }

  items { _items }
  items=(value) { _items = value }

  requiresScrollBar { _items.count > _visibleItemCapacity }

  update() {
    if (Hotkey["down"].justPressed) {
      _selectedIndex = _selectedIndex + 1
    } else if (Hotkey["up"].justPressed) {
      _selectedIndex = _selectedIndex - 1
    }
    _selectedIndex = Math.clamp(_selectedIndex, 0, _items.count - 1)

    if (requiresScrollBar) {
      if (_selectedIndex >= (_scrollPosition + _visibleItemCapacity)) {
        _scrollPosition = _selectedIndex - _visibleItemCapacity + 1
      } else if (_selectedIndex <= _scrollPosition) {
        _scrollPosition = _selectedIndex
      }
    }
  }

  draw(x, y) {
    Canvas.print(title, x + 6, y, isFocused ? AppColor.domePurple : AppColor.gray)
    y = y + 10

    if (_items.count == 0) {
      Canvas.print("no items", x + 6, y, AppColor.gray)
    } else {
      var itemY = y
      for (drawIndex in 0..._visibleItemCapacity) {
        var itemIndex = _scrollPosition + drawIndex
        if (itemIndex >= _items.count) {
          break
        }
        if (itemIndex == selectedIndex) {
          drawSelectionIndicator(x, itemY)
        }
        _drawItemFn.call(items[itemIndex], x + 6, itemY)
        itemY = itemY + 10
      }
    }
    if (requiresScrollBar) {
      drawScrollBar(x, y)
    }
  }

  drawSelectionIndicator(x, y) {
    Canvas.circle(x, y + 2, 2, isFocused ? AppColor.domePurple : AppColor.gray)
  }

  drawScrollBar(x, y) {
    // draw the border of the scroll bar
    x = x + 50
    var sbHeight = _visibleItemCapacity * 10 - 4
    var sbWidth = 4
    Canvas.rect(x, y, sbWidth, sbHeight, AppColor.foreground)
    // draw the filled in section indicating current focus
    var fillHeight = _visibleItemCapacity / _items.count * sbHeight
    var fillY = y + (_scrollPosition / _items.count * sbHeight)
    Canvas.rectfill(x, fillY, sbWidth, fillHeight, AppColor.foreground)
  }
}

class AnimationPanel {
  construct new(cellAnimationResource) {
    _res = cellAnimationResource
    _frameListFocused = false

    _animationsList = ListView.new("ANIMATIONS", _res.animations) {|item, x, y| 
      Canvas.print(item.name, x, y, AppColor.foreground)
    }
    _framesList = ListView.new("FRAMES", []) {|item, x, y| 
      Canvas.print(item.cluster, x, y, AppColor.foreground)
      Canvas.print(item.duration.toString, x + 40, y, AppColor.foreground)
    }
    _framesList.isFocused = false
  }

  selection { _animationsList.selectedIndex }
  framesListFocused { _framesList.isFocused }
  selectedAnim { _animationsList.selectedItem }
  selectedFrame { _framesList.selectedItem }

  update() {
    if (_animationsList.isFocused) {
      updateAnimFocused()
    } else {
      updateFrameFocused()
    }
  }

  updateAnimFocused() {
    if (Keyboard["return"].justPressed) {
      // select frame
      _framesList.isFocused = true
      _animationsList.isFocused = false
    } else {
      _animationsList.update()
      _framesList.items = _animationsList.selectedItem.frames
    }
  }

  updateFrameFocused() {
    if (Keyboard["escape"].justPressed) {
      // return to animations list
      _framesList.isFocused = false
      _animationsList.isFocused = true
    } else {
      _framesList.update()
    }
  }

  draw(x, y) {
    _animationsList.draw(x + 15, y + 130)
    _framesList.draw(x + 80, y + 130)
  }
}

class ClusterPanel {
  construct new(cellAnimationResource) {
    _res = cellAnimationResource
    
    _clustersList = ListView.new("CLUSTERS", _res.clusters) {|item, x, y| 
      Canvas.print(item.name, x, y, AppColor.foreground)
    }
    _cellsList = ListView.new("CELLS", []) {|item, x, y| 
      Canvas.print("[%(item.x),%(item.y),%(item.width),%(item.height)]", x, y, AppColor.foreground)
    }
    _cellsList.isFocused = false
  }

  selection { _clustersList.selectedIndex }
  selectedCluster { _clustersList.selectedItem }
  cellsListFocused { _cellsList.isFocused }
  selectedCell { _cellsList.selectedItem }

  update() {
    if (_clustersList.isFocused) {
      updateClustersFocused()
    } else {
      updateCellsFocused()
    }
  }

  updateClustersFocused() {
    if (Keyboard["return"].justPressed) {
      // select frame
      _cellsList.isFocused = true
      _clustersList.isFocused = false
    } else {
      _clustersList.update()
      _cellsList.items = _clustersList.selectedItem.cells
    }
  }

  updateCellsFocused() {
    if (Keyboard["escape"].justPressed) {
      // return to animations list
      _cellsList.isFocused = false
      _clustersList.isFocused = true
    } else {
      _cellsList.update()
    }
  }

  draw(x, y) {
    _clustersList.draw(x + 15, y + 130)
    _cellsList.draw(x + 80, y + 130)
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
    _all = true
  }

  update() {
    _cellAnimationResource.update()
    if (Keyboard["a"].justPressed) {
      _all = !_all
    }
    if (Hotkey["toggleBackground"].justPressed) {
      _drawBackground = !_drawBackground
    }
    if (Hotkey["switchMode"].justPressed) {
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

    if (_all) {
      _cellAnimationResource.draw(x, y)
    } else if (_currentPanel == _animationPanel) {
      if (_animationPanel.framesListFocused) {
        _cellAnimationResource.findCluster(_animationPanel.selectedFrame.cluster).draw(x, y)
      } else {
        _cellAnimationResource.drawAnimation(x, y, _animationPanel.selection)
      }
    } else {
      _clusterPanel.selectedCluster.draw(x, y)
    }

    if (_currentPanel == _clusterPanel && _clusterPanel.cellsListFocused) {
      var selectedCell = _clusterPanel.selectedCell
      for (cell in _clusterPanel.selectedCluster.cells) {
        Canvas.rect(cell.x, cell.y, cell.width, cell.height, cell == selectedCell ? AppColor.domePurple : AppColor.gray)
      }
    }

    _currentPanel.draw(x, y)
  }
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