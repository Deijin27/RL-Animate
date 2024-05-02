import "graphics" for Canvas, Color, ImageData, Font
import "input" for Keyboard, Mouse
import "io" for FileSystem
import "cell_animation" for CellAnimationResource, CellFormat, Animation, Frame
import "dome" for Process, Window, Log
import "controls" for AppColor, Button, AppFont, ListView, Hotkey, Menu
import "math" for Math

class AnimationPanelState {
  list { 0 }
  menu { 1 }
  move { 2 }
  rename { 3 }
}

class AnimationPanel {

  name { "ANIMATIONS" }

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
    _state = "list"

    _animStateActions = {
      "list": Fn.new { 
        updateAnimFocused() 
      },
      "rename" : Fn.new {
        // TODO
      },
      "menu" : Fn.new {
        _menu.update()
        if (_menu.complete) {
          if (_menu.proceed) {
             _animMenuActions[_menu.selected].call()
          } else {
            _state = "list"
          }
          _menu = null
        }
      },
      "move" : Fn.new {
        if (Hotkey["navigateBack"].justPressed) {
          _state = "list"
          _animationsList.moving = false
        } else {
          _animationsList.update()
        }
      },
    }

    _frameStateActions = {
      "list": Fn.new { 
        updateFrameFocused() 
      },
      "menu": Fn.new {
       _menu.update()
        if (_menu.complete) {
          if (_menu.proceed) {
             _frameMenuActions[_menu.selected].call()
          } else {
            _state = "list"
          }
          _menu = null
        }
      },
      "move" : Fn.new {
        if (Hotkey["navigateBack"].justPressed) {
          _state = "list"
          _animationsList.moving = false
        } else {
          _animationsList.update()
        }
      }
    }

    _animMenuActions = {
      "Add": Fn.new {
        var targetPos = _animationsList.items.count > 0 ? _animationsList.selectedIndex + 1 : 0
        _animationsList.items.insert(Animation.new(), _animationsList.selectedIndex + 1)
        _state = "rename"
      },
      "Rename" : Fn.new {
        _state = "rename"
      },
      "Move" : Fn.new {
        _state = "move"
        _animationsList.moving = true
      },
      "Delete": Fn.new {
        _animationsList.items.removeAt(_animationsList.selectedIndex)
        _state = "list"
      },
      "Duplicate": Fn.new {
        var targetPos = _animationsList.items.count > 0 ? _animationsList.selectedIndex + 1 : 0
        _animationsList.items.insert(Animation.clone(), _animationsList.selectedIndex + 1)
        _state = "rename"
      }
    }

    _frameMenuActions = {
      "Add": Fn.new {
        var targetPos = _framesList.items.count > 0 ? _framesList.selectedIndex + 1 : 0
        _framesList.items.insert(Frame.new(), targetPos)
        _state = "list"
      },
      "Move" : Fn.new {
        _state = "move"
        _framesList.moving = true
      },
      "Delete": Fn.new {
        _framesList.items.removeAt(_framesList.selectedIndex)
        _res.reset()
        _state = "list"
      },
      "Duplicate": Fn.new {
        var targetPos = _framesList.items.count > 0 ? _framesList.selectedIndex + 1 : 0
        _framesList.items.insert(selectedFrame.clone(), targetPos)
        _state = "list"
      }
    }
  }

  selection { _animationsList.selectedIndex }
  framesListFocused { _framesList.isFocused }
  selectedAnim { _animationsList.selectedItem }
  selectedFrame { _framesList.selectedItem }

  update() {
    if (_animationsList.isFocused) {
      _animStateActions[_state].call()
    } else {
      _frameStateActions[_state].call()
    }
  }

  updateAnimFocused() {
    if (Hotkey["menu"].justPressed) {
      _menu = _animationsList.items.count == 0 ? Menu.new(["Add"]) : Menu.new(["Add", "Move", "Delete", "Duplicate"])
      _state = "menu"
    } else if (_animationsList.items.count > 0 && Hotkey["navigateForward"].justPressed) {
      // select frame
      _framesList.isFocused = true
      _animationsList.isFocused = false
    } else {
      _animationsList.update()
      var sa = selectedAnim
      if (sa != null) {
        _framesList.items = sa.frames
      } else {
        _framesList.items = []
      }
    }
  }

  updateFrameFocused() {
    if (Hotkey["menu"].justPressed) {
      _menu = _framesList.items.count == 0 ? Menu.new(["Add"]) : Menu.new(["Add", "Rename", "Move", "Delete", "Duplicate"])
      _state = "menu"
    } else if (Hotkey["right"].justPressed) {
      changeFrameClusterId(selectedFrame, 1)
    } else if (Hotkey["left"].justPressed) {
      changeFrameClusterId(selectedFrame, -1)
    } else if (Hotkey["navigateBack"].justPressed) {
      // return to animations list
      _framesList.isFocused = false
      _animationsList.isFocused = true
    } else {
      _framesList.update()
    }
  }

  changeFrameClusterId(frame, change) {
    var clusterIndex = _res.findClusterIndex(frame.cluster) + change
    if (clusterIndex >= _res.clusters.count) {
      clusterIndex = 0
    } else if (clusterIndex < 0) {
      clusterIndex = _res.clusters.count - 1
    }
    frame.cluster = _res.clusters[clusterIndex].name
  }

  draw(x, y) {
    _animationsList.draw(x, y)
    _framesList.draw(x + 65, y)
    if (_menu != null) {
      _menu.draw(220, 180)
    }
  }
}

class ClusterInfoForm {
  construct new() {
    _isFocused = false
    _title = "FILE"
  }
  title { _title }
  isFocused { _isFocused }
  isFocused=(value) { _isFocused = value }
  cluster { _cluster }
  cluster=(value) { _cluster = value }

  update() {
    
  }

  draw(x, y) {
    Canvas.print(title, x + 6, y, isFocused ? AppColor.domePurple : AppColor.gray)
    y = y + 10
    Canvas.print(_cluster.file, x + 6, y, AppColor.foreground)
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
    _clusterInfo = ClusterInfoForm.new()
    _cellsList.isFocused = false
    _clusterInfo.isFocused = false
  }

  name { "CLUSTERS" }

  selection { _clustersList.selectedIndex }
  selectedCluster { _clustersList.selectedItem }
  cellFileFocused { _cellFileFocused }
  cellsListFocused { _cellsList.isFocused }
  selectedCell { _cellsList.selectedItem }

  update() {
    if (_clustersList.isFocused) {
      updateClustersFocused()
    } else if (_cellsList.isFocused) {
      updateCellsFocused()
    } else if (_clusterInfo.isFocused) {
      updateClusterInfoFocused()
    }
  }

  updateClustersFocused() {
    if (Hotkey["navigateForward"].justPressed) {
      _clusterInfo.isFocused = true
      _clustersList.isFocused = false
    } else {
      _clustersList.update()
      var sc = _clustersList.selectedItem
      if (sc != null) {
        _cellsList.items = sc.cells
        _clusterInfo.cluster = sc
      } else {
        _cellsList.items = []
      }
    }
  }

  updateCellsFocused() {
    if (Hotkey["navigateBack"].justPressed) {
      _cellsList.isFocused = false
      _clusterInfo.isFocused = true
    } else {
      _cellsList.update()
    }
  }

  updateClusterInfoFocused() {
    if (Hotkey["navigateForward"].justPressed) {
      _clusterInfo.isFocused = false
      _cellsList.isFocused = true
    } else if (Hotkey["navigateBack"].justPressed) {
      _clusterInfo.isFocused = false
      _clustersList.isFocused = true
    } else {
      _clusterInfo.update()
    }
  }

  draw(x, y) {
    _clustersList.draw(x, y)

    var cellsListY = y
    var clusterInfoX = x + 65
    if (_res.format == CellFormat.oneImagePerCluster) {
      cellsListY = cellsListY + 20
      _clusterInfo.draw(clusterInfoX, y)
    }
    _cellsList.draw(clusterInfoX, cellsListY)
  }
}

class CellAnimationState {
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
    if (Hotkey["toggleAllAnimations"].justPressed) {
      _all = !_all
    }
    if (Hotkey["toggleBackground"].justPressed) {
      _drawBackground = !_drawBackground
    }
    if (Hotkey["left"].justPressed || Hotkey["right"].justPressed) {
      if (_currentPanel == _animationPanel) {
        _currentPanel = _clusterPanel
      } else {
        _currentPanel = _animationPanel
      }
    }
    _currentPanel.update()
  }

  draw(dt) {
    drawImg(2, 2)
    drawTopBar(0, 124)
    _currentPanel.draw(10, 140)
  }

  drawTopBar(x, y) {
    // background
    Canvas.rectfill(0, y, 400, 9, AppColor.raisedBackground)
    Canvas.line(0, y, 400, y, AppColor.gray)
    Canvas.line(0, y + 8, 400, y + 8, AppColor.gray)
    
    // left text
    Canvas.print("EDIT ANIMATION", 5, y + 2, AppColor.foreground)

    // right text
    var text = "<< " + _currentPanel.name + " >>"
    var textWidth = Font[Canvas.font].getArea(text).x

    Canvas.print(text, 200 - textWidth / 2, y + 2, AppColor.domePurple)
  }

  drawImg(x, y) {
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

    if (_currentPanel == _clusterPanel) {
      var selectedCell = _clusterPanel.selectedCell
      for (cell in _clusterPanel.selectedCluster.cells) {
        Canvas.rect(x + cell.x, y + cell.y, cell.width, cell.height, (_clusterPanel.cellsListFocused && cell == selectedCell) ? AppColor.domePurple : AppColor.gray)
      }
    }
  }
}