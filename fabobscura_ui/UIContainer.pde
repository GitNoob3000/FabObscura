class UIContainer {
  ArrayList <UIBox> uiboxes;
  ArrayList <Connector> uiconnectors;
  float spacing;
  float x;
  float y;
  int last = -1;
  int idx;
  float w, h; // height and width

  UIContainer(int idx_, float x_, float y_, float spacing_) {
    idx = idx_;
    x = x_;
    y = y_;
    spacing = spacing_;

    uiboxes = new ArrayList<UIBox>();
    uiconnectors = new ArrayList<Connector>();
  }
  
  void removeLast() {
    UIBox last = uiboxes.get(uiboxes.size()-1); 
    w -= last.w + spacing;
    uiboxes.remove(uiboxes.size()-1); 
  }

  void addBox(String label, float w, float h, color labelColor) {
    int numboxes =  uiboxes.size();

    this.w += w + spacing;
    this.h = max(this.h, h);

    float boxX = x + w/2;
    if (numboxes > 0) {
      boxX = uiboxes.get(numboxes-1).x + uiboxes.get(numboxes-1).w/2 + w/2 + spacing;
    }
    UIBox box = new UIBox(label, boxX, y, w, h, labelColor);
    uiboxes.add(box);

    if (label.equals("PLOT")) barrierpatterns.get(idx).setPos(boxX - w*0.95 - spacing, y - h*0.95);
    else if (label.equals("animation")) {
      ScrollableList folderDropdown = cp5.addScrollableList("folderDropdown"+idx)
        .setColorBackground(color(140, 100, 255))
        .setItems(folders)
        .setCaptionLabel("animation folder")
        .setPosition(x + 3, y - h*0.3)
        .setValue(0);

      if (idx == 0) folderDropdown.setSize(int(w)-6, 100);
      else {
        cp5.getController("folderDropdown0").setSize(int(w/2)-6, 100);
        
        folderDropdown.setSize(int(w/2)-6, 100)
                      .setPosition(x + 3 + w/2, cp5.getController("folderDropdown0").getPosition()[1]);
      }
    } else if (label.equals("pattern unit")) {
      // Create text entry box
      float xpos = boxX + spacing - w/2 + 20;

      int itemwidth = int(boxX+w/2-xpos) - 4;
      float gap = 5;
      int itemheight = int(h*0.6-gap);
      float ypos = y - h/2 + 4;
      cp5.addTextfield("userFunction"+idx)
        .setPosition(xpos, ypos)
        .setText("0")
        .setSize(itemwidth, itemheight)
        .setLabel("")
        .setColor(color(255))
        .setColorActive(color(unhex("ff00ec9f")))
        .setColorBackground(color(40))
        .setColorForeground(color(unhex("aa00ec9f")))
        .setAutoClear(false)
        .setFont(customFont);

      cp5.addSlider("density"+idx)
        .setSize(itemwidth-35, int(h-itemheight-gap-10))
        .setLabel("")
        .setColorActive(color(unhex("ff00ec9f")))
        .setColorBackground(color(40))
        .setColorForeground(color(unhex("aa00ec9f")))
        .setPosition(xpos +35, ypos+itemheight+gap)
        .setRange(1, 100)
        .setValue(50)
        ;
    } else if (label.equals("direction")) {
      float knobval = 0;
      if(idx > 0) knobval = cp5.get(Knob.class, "rotationAngle0").getValue() + 90;
      
      cp5.addKnob("rotationAngle"+idx)
        .setRange(-90, 90)
        .setValue(knobval)
        .setPosition(boxX - w/3, y - w/3)
        .setRadius(w/3)
        .setNumberOfTickMarks(10)
        .setTickMarkLength(4)
        .setLabel("")
        .setColorForeground(color(255))
        .setColorBackground(color(unhex("ff34bfff")))
        .setColorActive(color(255, 255, 0))
        .setDragDirection(Knob.HORIZONTAL)
        ;
    }

  }

  void display() {
    rectMode(CENTER);
    float shift = 0;

    for (UIBox box : uiboxes) {
      stroke(unhex("ff514958"));
      strokeWeight(2);
      line(x+shift + box.w, y, x+shift + box.w + spacing, y);

      box.display(idx == 0, idx > 0 && box.label.equals("animation"));

      if (box.label.equals("PLOT")) barrierpatterns.get(idx).display();

      shift += spacing + box.w;
    }
    
    if(idx > 0) {
      UIContainer container = uicontainers.get(0); 
      stroke(unhex("ff514958"));
      strokeWeight(2);
      line(x+120, y, x+120, y-container.h/2-10);
      line(x+120, y-container.h/2-10, x + container.w, y-container.h/2-10);
      line(x + container.w, y-container.h/2-10, x + container.w, container.y);
    }

  }
}
