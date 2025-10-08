class UIBox {
  float w, h, x, y;
  String label;
  color labelColor;

  UIBox(String label, float x_, float y_, float w, float h, color labelColor) {
    this.label = label;
    x = x_;
    y = y_;

    this.w = w;
    this.h = h;
    this.labelColor = labelColor;
  }
  
  void setHeight(float h_) {
    h = h_; 
  }
  
  void setY(float y_) {
    y = y_; 
  }


  void display(boolean showLabel, boolean hideBox) {
    rectMode(CENTER);
    shapeMode(CENTER);
    strokeWeight(1);
    stroke(unhex("ffdfd9fc"));
    fill(255, 255, 255, 10);
    
    if(!hideBox) rect(x, y, w, h, 3);

    fill(labelColor);
    textSize(16);

    if (label.equals("pattern unit")) {
      text("f(x)=", x - w/2 + 5, y - 5);
      text("resolution:", x - w/2 + 5, y+h/2-8);
    }

    if (showLabel) {
      text(label, x - w/2, y - h / 2 - 5);
    }
  }
}
