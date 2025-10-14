class Connector {
  UIBox startpoint, endpoint;
  boolean arrow;
  float x,y; 

  Connector(UIBox startpoint, UIBox endpoint, boolean arrow) {
    this.startpoint = startpoint;
    this.endpoint = endpoint;
    this.arrow = arrow;
  }

  void display() {
    stroke(100);
    strokeWeight(2);
    float x1 = startpoint.x + startpoint.w / 2;
    float y1 = startpoint.y;
    float x2 = endpoint.x - endpoint.w / 2;
    float y2 = endpoint.y;

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
