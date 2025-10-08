class Connector {
  UIBox from, to;
  boolean arrow;
  float x,y; 

  Connector(UIBox from, UIBox to, boolean arrow) {
    this.from = from;
    this.to = to;
    this.arrow = arrow;
  }

  void display() {
    stroke(100);
    strokeWeight(2);
    float x1 = from.x + from.w / 2;
    float y1 = from.y;
    float x2 = to.x - to.w / 2;
    float y2 = to.y;

    line(x1, y1, x2, y2);

    if (arrow) {
      drawArrow(x2, y2);
    }
  }

  void drawArrow(float x, float y) {
    float arrowSize = 10;
    stroke(255, 180, 0);
    strokeWeight(3);
    line(x - arrowSize, y - arrowSize/2, x, y);
    line(x - arrowSize, y + arrowSize/2, x, y);
  }
}
