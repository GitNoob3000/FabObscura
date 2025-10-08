

class PatternUnit {
  PApplet parent;
  GPlot patternunit;
  //float rotationAngle = 45; // Rotate 45 degrees as an example
  int numPoints = 200;
  GPointsArray points;
  float resolution;
  float xMin = 0;
  float xMax = 10;
  String userFunction = "0";

  public PatternUnit(GPlot plot) {
    patternunit = plot;
    //resolution = resolution_;
    points = new GPointsArray(numPoints);

    patternunit.setDim(70, 70);
    patternunit.getXAxis().setNTicks(4);
    patternunit.getYAxis().setNTicks(4);
    patternunit.setLineColor(color(unhex("ff00ec9f")));
    patternunit.setPointSize(0);
    patternunit.setBgColor(0);
    patternunit.setLineWidth(2);
    patternunit.setGridLineColor(color(unhex("ff514958")));

    updatePlot();
  }
  
  void setPos(float x, float y) {
    patternunit.setPos(x, y);
  }

  void setFunction(String userFunction_) {
    userFunction = userFunction_;
    updatePlot();
  }


  void display() {
    patternunit.beginDraw();
    patternunit.drawGridLines(GPlot.BOTH);
    patternunit.drawLines();
    patternunit.endDraw();
  }

  void updatePlot() {
    int numPoints = 200;
    GPointsArray points = new GPointsArray(numPoints);

    float xMin = 0;
    float xMax = 1;
    float step = (xMax - xMin) / (numPoints - 1);

    // Prepare the expression parser
    Argument x = new Argument("x");
    Expression exp = new Expression(userFunction, x);

    if (!exp.checkSyntax()) {
      println("Syntax error: " + exp.getErrorMessage());
      return;
    }

    for (int i = 0; i < numPoints; i++) {
      float xVal = xMin + i * step;
      x.setArgumentValue(xVal);
      double yVal = exp.calculate();

      if (!Double.isNaN(yVal) && !Double.isInfinite(yVal))
        points.add(xVal, (float) yVal);
    }

    patternunit.setPoints(points);
  }
}
