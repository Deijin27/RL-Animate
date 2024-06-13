import "graphics" for Canvas, Color, ImageData, Font
import "input" for Keyboard, Mouse
import "io" for FileSystem
import "cell_animation" for CellAnimationResource, CellFormat, Animation, Frame
import "dome" for Process, Window, Log
import "controls" for AppColor, Button, AppFont, ListView, Hotkey, Menu, TextInputDialog
import "math" for Math
import "cell_animation_views/cluster_panel" for ClusterPanel
import "cell_animation_views/animation_panel" for AnimationPanel
import "cell_animation_views/settings_panel" for SettingsPanel

class CellAnimationState {
  construct new(dir, animationFile) {
    _dir = dir
    _animationFile = animationFile
    _drawBackground = true
    _cellAnimationResource = CellAnimationResource.new(animationFile, dir)
    _animationPanel = AnimationPanel.new(_cellAnimationResource)
    _clusterPanel = ClusterPanel.new(_cellAnimationResource)
    _settingsPanel = SettingsPanel.new(_cellAnimationResource)
    _panels = [_animationPanel, _clusterPanel, _settingsPanel]
    _currentPanel = _animationPanel
    _all = true
    _updateCounter = 0
  }

  save() {
    _cellAnimationResource.save(_animationFile + ".test.xml")
  }

  cyclePanel(change) {
    var currentIndex = _panels.indexOf(_currentPanel)
    currentIndex = currentIndex + change
    if (currentIndex < 0) {
      currentIndex = _panels.count - 1
    } else if (currentIndex >= _panels.count) {
      currentIndex = 0
    }
    _currentPanel = _panels[currentIndex]
  }

  update() {
    if (Keyboard["q"].justPressed) {
      save()
    }
    _cellAnimationResource.update()
    if (Hotkey["toggleAllAnimations"].justPressed) {
      _all = !_all
    }
    if (Hotkey["toggleBackground"].justPressed) {
      _drawBackground = !_drawBackground
    }
    if (allowSwapPanel) {
      if (Hotkey["left"].justPressed) {
        cyclePanel(-1)
      } else if (Hotkey["right"].justPressed) {
        cyclePanel(1)
      }
    }
    _currentPanel.update()
    _updateCounter = _updateCounter + 1
  }

  draw(dt) {
    var areaW = 600
    var areaH = 124
    drawBackground(areaW, areaH)
    drawImg(2, 2, areaW, areaH)
    drawTopBar(0, 124)
    _currentPanel.draw(10, 140)
    drawBottomBar()
  }

  drawBottomBar() {
    var h = Canvas.height
    var top = h - 14
    var w = Canvas.width
    Canvas.rectfill(0, top, w, 14, Color.hex("#202020"))
    Canvas.line(0, top, w, top, Color.black)
  }

  background { _cellAnimationResource.backgroundImage }

  drawBackground(areaW, areaH) {
    //Canvas.rectfill(0, 124, 600, 200, Color.hex("#817bb7"))
    var gridPos = 0 - (_updateCounter / 7) % 7 
    drawGrid(gridPos, areaH, areaW, 200, 7, Color.hex("#585289"), Color.hex("#3c3768"))
    drawCheckerboard(0, 0, areaW, areaH, 6, Color.black, Color.hex("#101010"))
    //Canvas.line(6, 0, 6, 124, Color.red)
    //Canvas.line(0, 6, 600, 6, Color.blue)
  }

  drawGrid(x, y, w, h, squareSize, bgColor, lineColor) {
    Canvas.rectfill(x, y, w, h, bgColor)
    var lx = 0
    while (lx < w) {
      lx = lx + squareSize
      Canvas.line(x + lx, y, x + lx, y + h, lineColor)
    }
    var ly = 0
    while (ly < h) {
      Canvas.line(x, y + ly, x + w, y + ly, lineColor)
      ly = ly + squareSize
    }
  }

  drawCheckerboard(x, y, w, h, squareSize, color1, color2) {
   var floorX = (w / squareSize).floor + 1
   var floorY = (h / squareSize).floor + 1
   Canvas.rectfill(x, y, w, h, color1)
   var even = floorY % 2 == 0
   var altern = false
   for (i in 0...floorX) {
    var xPos = x + i * squareSize
    for (j in 0...floorY) {
      if (altern) {
        Canvas.rectfill(xPos, y + j * squareSize, squareSize, squareSize, color2)
      }
      altern = !altern
    }
    if (even) {
      altern = !altern
    }
   }
  }

  allowSwapPanel { _currentPanel.allowSwapPanel }

  drawTopBar(x, y) {
    // background
    Canvas.rectfill(0, y, 400, 11, AppColor.raisedBackground)
    Canvas.line(0, y, 400, y, AppColor.domePurple)
    Canvas.line(0, y - 1, 400, y - 1, Color.black)
    Canvas.line(0, y + 10, 400, y + 10, AppColor.domePurple)
    Canvas.line(0, y + 11, 400, y + 11, Color.black)
    
    // left text
    Canvas.print("EDIT ANIMATION", 5, y + 3, AppColor.foreground)

    // right text
    var text = "<< " + _currentPanel.name + " >>"
    var textWidth = Font[Canvas.font].getArea(text).x

    Canvas.print(text, 200 - textWidth / 2, y + 3, allowSwapPanel ? AppColor.gamer : AppColor.gray)
  }

  drawImg(x, y, areaW, areaH) {
    if (background != null && _drawBackground) {
      Canvas.draw(background, x, y)
    }

    if (_all) {
      _cellAnimationResource.draw(x, y)
    } else if (_currentPanel == _animationPanel) {
      if (_animationPanel.drawSelectedFrame) {
        _animationPanel.selectedFrame.cluster.draw(x, y)
      } else {
        _cellAnimationResource.drawAnimation(x, y, _animationPanel.selection)
      }
    } else {
      _clusterPanel.selectedCluster.drawFull(x, y)
    }

    if (_currentPanel == _clusterPanel) {
      if (_clusterPanel.highlightSelectedCell) {
        var sc = _clusterPanel.selectedCell
        if (sc != null) {
          drawShadowBorder(0, 0, areaW, areaH, x + sc.x, y + sc.y, sc.width, sc.height)
        } else {
          drawShadowBorder(0, 0, areaW, areaH, 0, 0, 0, 0)
        }
      }
      var selectedCell = _clusterPanel.selectedCell
      for (cell in _clusterPanel.selectedCluster.cells) {
        Canvas.rect(x + cell.x, y + cell.y, cell.width, cell.height, (_clusterPanel.highlightSelectedCell && cell != selectedCell) ? AppColor.shadowGray : AppColor.shadowWhite)
      }
    }
  }

  drawShadowBorder(x, y, w, h, cx, cy, cw, ch) {
    if (cw == 0 || ch == 0) {
      Canvas.rectfill(x, y, w, h, AppColor.shadow)
      return
    }
    var lw = cx - x
    var rw = (x + w) - (cx + cw)
    var th = cy - y
    var bh = (y + h) - (cy + ch)

    // top
    if (th > 0) {
      Canvas.rectfill(x, y, w, th, AppColor.shadow)
    }
    // left
    if (lw > 0) {
      Canvas.rectfill(x, cy, lw, ch, AppColor.shadow)
    }
    // right
    if (rw > 0) {
      Canvas.rectfill(cx + cw, cy, rw, ch, AppColor.shadow)
    }
    // bottom
    if (bh > 0) {
      Canvas.rectfill(x, cy + ch, w, bh, AppColor.shadow)
    }
  }
}