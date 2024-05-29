import "graphics" for Canvas, Color, ImageData, Font
import "input" for Keyboard, Mouse
import "io" for FileSystem
import "cell_animation" for CellAnimationResource, CellFormat, Animation, Frame
import "dome" for Process, Window, Log
import "controls" for AppColor, Button, AppFont, ListView, Hotkey, Menu, TextInputDialog
import "math" for Math
import "cell_animation_views/cluster_panel" for ClusterPanel
import "cell_animation_views/animation_panel" for AnimationPanel

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
    _updateCounter = 0
  }

  update() {
    _cellAnimationResource.update()
    if (Hotkey["toggleAllAnimations"].justPressed) {
      _all = !_all
    }
    if (Hotkey["toggleBackground"].justPressed) {
      _drawBackground = !_drawBackground
    }
    if (allowSwapPanel && (Hotkey["left"].justPressed || Hotkey["right"].justPressed)) {
      if (_currentPanel == _animationPanel) {
        _currentPanel = _clusterPanel
      } else {
        _currentPanel = _animationPanel
      }
    }
    _currentPanel.update()
    _updateCounter = _updateCounter + 1
  }

  draw(dt) {
    drawBackground()
    drawImg(2, 2)
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

  drawBackground() {
    //Canvas.rectfill(0, 124, 600, 200, Color.hex("#817bb7"))
    var gridPos = 0 - (_updateCounter / 7) % 7 
    drawGrid(gridPos, 124, 600, 200, 7, Color.hex("#585289"), Color.hex("#3c3768"))
    drawCheckerboard(0, 0, 600, 124, 6, Color.black, Color.hex("#101010"))
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

  drawImg(x, y) {
    if (_background != null && _drawBackground) {
      Canvas.draw(_background, x, y)
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
      _clusterPanel.selectedCluster.draw(x, y)
    }

    if (_currentPanel == _clusterPanel) {
      var selectedCell = _clusterPanel.selectedCell
      for (cell in _clusterPanel.selectedCluster.cells) {
        Canvas.rect(x + cell.x, y + cell.y, cell.width, cell.height, (_clusterPanel.highlightSelectedCell && cell == selectedCell) ? AppColor.gamer : AppColor.gray)
      }
    }
  }
}