import processing.pdf.*;

import controlP5.*;
import java.io.File;
import java.util.*;
import processing.svg.*;
import grafica.*;
import org.mariuszgromada.math.mxparser.*;
import java.net.URLEncoder;

PApplet secondaryApplet;

ControlP5 cp5;
Button makeButton;
Button addButton;
Slider planeDistSlider;
Slider viewDistSlider;
Slider fovSlider;

Textfield function1, function2;

color bgcolor = 0;

PImage back_plane;
PImage back_plane_viewpoint;
PImage front_plane;
PImage nest_plane;
PImage back_plane_radial;
PImage front_plane_radial;

PImage layer3;
PImage scrambled_resize;
PImage scrambled_structure_resize;

boolean diagram = false;
boolean mouseControl = true;
boolean movingNestBarrier = false;

float lastPosX = 0;
float lastPosY = 0;
float lastPosNestX = 0;
float lastPosNestY = 0;

//int ren_ppi = 360; //the ppi of the renderer
int ren_ppi = 300;

int gapwidth = 30;
float gapwidth_irl = gapwidth/(float) ren_ppi; // gap width in inches

//acrylic dimensions in pixels
int boxW;
int boxH;
int boxD;

int oldW;
int oldH;

// distance between front and back planes in inches
float plane_distance = 0.125;

// viewing distance in inches (default: 20)
float distance = 20;

float zoom = 1f;

// Initial field of view
float fov = radians(15);
float cameraZ;

float scale_factor = 1;

PGraphics cut;

float rotateX = 0;
float rotateY = 0;

boolean freezeViewpoint = false;

// Set up perspective projection with adjustable FOV
float aspect = float(width)/float(height);

int SLIDING = 1;
int PARALLAX = 2;
int ROTATION = 3;
int WEAVING = 1;
int TILING = 2;

int mode = SLIDING;
int operation = WEAVING;

PImage background;

ArrayList <PatternUnit> barrierpatterns;
GPlot patternunit;

ArrayList <UIContainer> uicontainers;

PFont pixelOp;
PFont customFont;

// Values to pass to Python script
List folders;
float rotationAngle0 = 0;
float rotationAngle1 = 0;
//float resolution = 5;

// check whether files have been updated
boolean checkInterlaced = false;
boolean checkPattern = false;
boolean checkRadialInterlaced = false;
boolean checkRadialPattern = false;

long previousModifiedInterlaced;
long previousModifiedPattern;
long previousModifiedRadialInterlaced;
long previousModifiedRadialPattern;

File interlacedfile;
File patternfile;
File radialinterlacedfile;
File radialpatternfile;

PGraphics pg;
PGraphics pg3D;

float imgPosX;
float imgPosY;

void settings() {
  size(800, 800, P3D);
  smooth(8);
  pixelDensity(2);
  License.iConfirmNonCommercialUse("Ticha Sethapakdi");
}

void resetFileTimestamps() {
  checkInterlaced = true;
  checkPattern = true;
  checkRadialInterlaced = true;
  checkRadialPattern = true;
}

void setupFiles() {
  interlacedfile = new File(dataPath("interlaced.png"));
  patternfile = new File(dataPath("pattern.png"));
  radialinterlacedfile = new File(dataPath("radial_composite.png"));
  radialpatternfile = new File(dataPath("radial_pattern.png"));

  previousModifiedInterlaced = interlacedfile.lastModified();
  previousModifiedPattern = patternfile.lastModified();
  previousModifiedRadialInterlaced = radialinterlacedfile.lastModified();
  previousModifiedRadialPattern = radialpatternfile.lastModified();
}

void setup() {
  pg = createGraphics(800, 800, P3D);
  surface.setTitle("FabObscura");

  pixelOp = createFont("PixelOperator.ttf", 20);
  customFont = createFont("PixelOperator.ttf", 10);
  textFont(pixelOp);

  setupFiles();

  imgPosX = width/2;
  imgPosY = height*0.55;

  //fov = PI/2;
  // Set initial FOV and calculate cameraZ for initial perspective
  cameraZ = (height/2.0) / tan(fov/2.0);

  // special parameters for making diagrams in the paper
  if (diagram) boxD = round(ren_ppi*1.25);

  back_plane = loadImage("interlaced.png");
  front_plane = loadImage("pattern.png");
  back_plane_viewpoint = loadImage("interlaced.png");
  back_plane_radial = loadImage("radial_composite.png");
  front_plane_radial = loadImage("radial_pattern.png");
  nest_plane = loadImage("pattern-nest.png");

  // we assume that the front and back planes are of the same size
  // we also assume that the images are already in ren_ppi
  boxW = front_plane.width;
  boxH = front_plane.height;
  boxD = round(ren_ppi*plane_distance);

  oldW = back_plane.width;
  oldH = back_plane.height;

  imageMode(CENTER);
  rectMode(CENTER);
  shapeMode(CENTER);

  cp5 = new ControlP5(this);
  folders = listFolders(dataPath(""));

  // Set the default color scheme to yellow
  cp5.setColorForeground(color(unhex("fff55192")));  // Light yellow
  cp5.setColorBackground(color(255));    // Dark yellow
  cp5.setColorActive(color(245, 199, 17));         // Bright yellow when active
  cp5.setColorCaptionLabel(color(255));            // Black text

  fovSlider = cp5.addSlider("fov")
    .setColorBackground(color(33, 33, 33))
    .setPosition(20, height*0.9-20)
    .setValue(15)
    .setRange(12, 47)
    .setWidth(70)
    .setHeight(15)
    .setCaptionLabel("field of view (degrees)")
    .hide()
    ;

  viewDistSlider = cp5.addSlider("distance")
    .setColorBackground(color(33, 33, 33))
    .setPosition(20, height*0.9)
    .setValue(distance)
    .setRange(10, 80)
    .setWidth(70)
    .setHeight(15)
    .setCaptionLabel("viewing distance (in.)")
    .hide()
    ;

  planeDistSlider = cp5.addSlider("plane_distance")
    .setColorBackground(color(33, 33, 33))
    .setPosition(20, height*0.9+20)
    .setValue(0.125)
    .setRange(0.125, 12)
    .setWidth(70)
    .setHeight(15)
    .setCaptionLabel("barrier distance (in.)")
    .hide()
    ;

  makeButton = cp5.addButton("generate")
    .setPosition(640, 80)
    .setSize(100, 40)
    .setColorBackground(color(unhex("ffff6125")))    // Dark yellow
    .setColorCaptionLabel(color(255))
    .setLabel("GENERATE")
    .setFont(customFont);

  cp5.addRadioButton("interactionMode")
    .setPosition(width/2 - 55, height*0.9)
    .setSize(30, 30)
    .setColorBackground(color(unhex("44ff6125")))
    .setColorForeground(color(unhex("66ff6125")))
    .setColorActive(color(unhex("ffff6125")))
    .setColorLabel(color(255))
    .setItemsPerRow(3)
    .setSpacingColumn(10)
    .setSpacingRow(10)
    .addItem(" ", 1)
    .addItem("  ", 2)
    .addItem("   ", 3)
    .activate(" ")
    ;

  barrierpatterns = new ArrayList<PatternUnit>();
  barrierpatterns.add(new PatternUnit(new GPlot(this)));
  barrierpatterns.add(new PatternUnit(new GPlot(this)));

  for (PatternUnit pattern : barrierpatterns) pattern.setFunction("0");

  uicontainers = new ArrayList<UIContainer>();

  uicontainers.add(new UIContainer(0, width*0.1, 65, 30));
  uicontainers.get(0).addBox("animation", 120, 30, color(140, 100, 255));
  uicontainers.get(0).addBox("pattern unit", 150, 60, color(unhex("ff00ec9f")));
  uicontainers.get(0).addBox("PLOT", 80, 80, color(0, 0));
  uicontainers.get(0).addBox("direction", 80, 80, color(0, 150, 255));

  makeButton.setPosition(uicontainers.get(0).x+uicontainers.get(0).w, uicontainers.get(0).y - 20);

  addButton = cp5.addButton("add")
    .setPosition(cp5.getController("folderDropdown0").getPosition()[0]-45, cp5.getController("folderDropdown0").getPosition()[1])
    .setSize(35, 20)
    .setColorBackground(color(unhex("ffff6125")))    // Dark yellow
    .setColorCaptionLabel(color(255))
    .setLabel("+ add");
}

void update() {
  if (checkInterlaced) {
    long currentModifiedTime = interlacedfile.lastModified();
    if (currentModifiedTime != previousModifiedInterlaced) {
      previousModifiedInterlaced = currentModifiedTime;

      println("Interlaced File has been modified. Updating interface...");
      // Update your UI or reload your file here
      back_plane = loadImage("interlaced.png");
      back_plane_viewpoint = loadImage("interlaced.png");

      checkInterlaced = false;
    }
  }
  if (checkPattern) {
    long currentModifiedTime = patternfile.lastModified();
    if (currentModifiedTime != previousModifiedPattern) {
      previousModifiedPattern = currentModifiedTime;

      println("Pattern File has been modified. Updating interface...");
      // Update your UI or reload your file here
      front_plane = loadImage("pattern.png");
      nest_plane = loadImage("pattern-nest.png");

      boxW = front_plane.width;
      boxH = front_plane.height;
      boxD = round(ren_ppi*plane_distance);

      checkPattern = false;
    }
  }
  if (checkRadialInterlaced) {
    long currentModifiedTime = radialinterlacedfile.lastModified();
    if (currentModifiedTime != previousModifiedRadialInterlaced) {
      previousModifiedRadialInterlaced = currentModifiedTime;

      println("Radial Interlaced File has been modified. Updating interface...");
      // Update your UI or reload your file here
      back_plane_radial = loadImage("radial_composite.png");

      checkRadialInterlaced = false;
    }
  }
  if (checkRadialPattern) {
    long currentModifiedTime = radialpatternfile.lastModified();
    if (currentModifiedTime != previousModifiedRadialPattern) {
      previousModifiedRadialPattern = currentModifiedTime;

      println("Pattern File has been modified. Updating interface...");
      // Update your UI or reload your file here
      front_plane_radial = loadImage("radial_pattern.png");

      checkRadialPattern = false;
    }
  }
}

void draw() {
  update();
  background(bgcolor);

  noStroke();
  imageMode(CENTER);

  float scale = min((float)width*0.6 / front_plane.width, (float)height*0.6 / front_plane.height);
  int numcontainers = uicontainers.size();

  float angle1 = radians(rotationAngle1);
  float dy1 = cos(angle1);  // vertical influence
  float dx1 = sin(angle1);  // horizontal influence

  float offset1 = mouseY - imgPosY;

  if (mode == SLIDING) {

    pushMatrix();
    translate(imgPosX, imgPosY);

    image(back_plane, 0, 0, back_plane.width * scale, back_plane.height * scale);

    blendMode(MULTIPLY);

    int lastidx = numcontainers-1;
    if (mouseY > uicontainers.get(lastidx).x + uicontainers.get(lastidx).h + 50) {
      float angle = radians(rotationAngle0);
      float dy = cos(angle);  // vertical influence
      float dx = sin(angle);  // horizontal influence

      float offset = mouseY - imgPosY;

      if (movingNestBarrier) {
        image(front_plane, lastPosX, lastPosY, front_plane.width * scale, front_plane.height * scale);
        image(nest_plane, dx1*offset1, dy1*offset1, nest_plane.width * scale, nest_plane.height * scale);

        lastPosNestX = dx1*offset1;
        lastPosNestY = dy1*offset1;
      } else {
        image(front_plane, dx * offset, dy * offset, front_plane.width * scale, front_plane.height * scale);
        if (numcontainers > 1) image(nest_plane, lastPosNestX, lastPosNestY, nest_plane.width * scale, nest_plane.height * scale);

        lastPosX = dx*offset;
        lastPosY = dy*offset;
      }

      blendMode(NORMAL);
      noFill();
      stroke(255);
      strokeWeight(1);

      rect(movingNestBarrier ? dx1 * offset1 : dx * offset, movingNestBarrier ? dy1 * offset1 : dy * offset, front_plane.width* scale, front_plane.height* scale);
    } else {
      image(front_plane, 0, 0, front_plane.width* scale, front_plane.height* scale);
      if (numcontainers > 1) image(nest_plane, 0, 0, front_plane.width* scale, front_plane.height* scale);
      blendMode(NORMAL);
      noFill();
      stroke(255);
      strokeWeight(1);
      rect(0, 0, front_plane.width*scale, front_plane.height*scale);
    }

    popMatrix();

    fill(color(unhex("ffff6125")));
    textSize(16);
    text("sliding", width/2 - 65, height*0.9 + 45);
  } else if (mode == PARALLAX) {
    hint(ENABLE_DEPTH_SORT);
    noFill();
    boxD = round(ren_ppi*plane_distance);

    pushMatrix();
    float fov_rad = radians(fov);
    cameraZ = (height/2.0) / tan(fov_rad/2.0);
    perspective(fov_rad, aspect, cameraZ/10.0, cameraZ*10.0);

    translate(imgPosX, imgPosY, -distance*ren_ppi);

    if (!freezeViewpoint && mouseY < fovSlider.getPosition()[1]) {
      rotateY = map(mouseX, width, 0, PI/2, -PI/2);
      rotateX = map(mouseY+bgcolor, 0, height, PI/2, -PI/2);
    }

    rotateX(rotateX);
    rotateY(rotateY);

    // draw the back plane
    pushMatrix();
    translate(0, 0, -boxD);

    image(back_plane_viewpoint, 0, 0);

    popMatrix();

    // draw the sides of the tile
    pushMatrix();
    translate(0, 0, -boxD/2);
    noFill();
    stroke(255-bgcolor);
    strokeWeight(2);
    boxNoFrontBack(boxW, boxH, boxD);
    popMatrix();


    // draw the front plane
    pushMatrix();
    translate(0, 0, 0 );
    blendMode(MULTIPLY);

    image(front_plane, 0, 0);
    if (numcontainers > 1) {
      image(nest_plane, 0, 0);
    }

    popMatrix();
    popMatrix();

    blendMode(NORMAL);
    hint(DISABLE_DEPTH_SORT);
    ortho();

    fill(color(unhex("ffff6125")));
    textSize(16);
    text("viewpoint", width/2 - 25, height*0.9 + 45);
  } else {
    pushMatrix();
    translate(imgPosX, imgPosY);
    image(back_plane_radial, 0, 0, back_plane_radial.width*scale, back_plane_radial.height*scale);

    blendMode(MULTIPLY);

    float dx = mouseX - imgPosX;
    float dy = mouseY - imgPosY;
    float angle = atan2(dy, dx);  // Angle from center to mouse
    rotate(angle);
    image(front_plane_radial, 0, 0, front_plane_radial.width*scale, front_plane_radial.height*scale);

    blendMode(NORMAL);
    noFill();
    stroke(255);
    strokeWeight(1);
    ellipse(0, 0, front_plane_radial.width*scale, front_plane_radial.height*scale);

    popMatrix();

    if (numcontainers > 1) image(nest_plane, 0, 0, nest_plane.width*scale, nest_plane.height*scale);

    fill(color(unhex("ffff6125")));
    textSize(16);
    text("rotation", width/2 + 15, height*0.9 + 45);
  }

  drawStateLabels();

  for (UIContainer uicontainer : uicontainers) uicontainer.display();
}

void mouseReleased() {
  if (mouseButton == RIGHT) {
    freezeViewpoint = !freezeViewpoint;
  }

  if (mode == PARALLAX && mouseY > height*0.9 && mouseX < width*0.3) {
    scale_factor = rescale_backplane(2*ren_ppi, 2*ren_ppi, 11);

    back_plane_viewpoint.resize(round(back_plane.width*scale_factor), 0);
    back_plane_viewpoint.save("interlaced_scaled-"+scale_factor*100+".png");
  }
}

void keyReleased() {
  if (cp5.get(Textfield.class, "userFunction0").isActive()) {
    String textEntered = cp5.get(Textfield.class, "userFunction0").getText();
    barrierpatterns.get(0).setFunction(textEntered);
  } else if (cp5.get(Textfield.class, "userFunction1") != null &&
    cp5.get(Textfield.class, "userFunction1").isActive()) {
    String textEntered = cp5.get(Textfield.class, "userFunction1").getText();
    barrierpatterns.get(1).setFunction(textEntered);
  } else if (key == 'z' || key == 'Z') {
    fov -= 0.02;  // Zoom in by decreasing FOV
    println("fov: "+fov);
  } else if (key == 'x' || key == 'X') {
    fov += 0.02;  // Zoom out by increasing FOV
  } else if (keyCode == TAB) {
    movingNestBarrier = !movingNestBarrier;
  } else if (key == 'a') {
    scale_factor = rescale_backplane(back_plane.width, back_plane.height, fov);

    back_plane_viewpoint.resize(round(back_plane.width*scale_factor), 0);
    back_plane_viewpoint.save("interlaced_scaled-"+scale_factor*100+".png");
  }
}

// Helper function to draw a 3D box without front and back faces
void boxNoFrontBack(float w, float h, float d) {
  float halfW = w / 2;
  float halfH = h / 2;
  float halfD = d / 2;
  blendMode(NORMAL);
  //fill(0, 200);  // Color and transparency for the planes
  fill(255);

  // Left face
  drawFace(-halfW, -halfH, -halfD, -halfW, halfH, -halfD, -halfW, halfH, halfD, -halfW, -halfH, halfD);

  // Right face
  drawFace(halfW, -halfH, -halfD, halfW, halfH, -halfD, halfW, halfH, halfD, halfW, -halfH, halfD);

  // Top face
  drawFace(-halfW, -halfH, -halfD, halfW, -halfH, -halfD, halfW, -halfH, halfD, -halfW, -halfH, halfD);

  // Bottom face
  drawFace(-halfW, halfH, -halfD, halfW, halfH, -halfD, halfW, halfH, halfD, -halfW, halfH, halfD);
}


// Helper function to draw a face of the box
void drawFace(float x1, float y1, float z1,
  float x2, float y2, float z2,
  float x3, float y3, float z3,
  float x4, float y4, float z4) {
  beginShape();
  vertex(x1, y1, z1);
  vertex(x2, y2, z2);
  vertex(x3, y3, z3);
  vertex(x4, y4, z4);
  endShape(CLOSE);
}

void controlEvent(ControlEvent theEvent) {
  if (theEvent.isFrom(addButton)) {
    if (uicontainers.size() == 1) {
      uicontainers.add(new UIContainer(1, width*0.1, 65 + uicontainers.get(0).h + 20, 30));
      uicontainers.get(1).addBox("animation", 120, 30, color(140, 100, 255));
      uicontainers.get(1).addBox("pattern unit", 150, 60, color(unhex("ff00ec9f")));
      uicontainers.get(1).addBox("PLOT", 80, 80, color(0, 0));
      uicontainers.get(1).addBox("direction", 80, 80, color(0, 150, 255));

      addButton.setLabel("- del");

      makeButton.setPosition(uicontainers.get(1).x+uicontainers.get(1).w, uicontainers.get(1).y-20);
    } else {
      cp5.remove("folderDropdown1");
      cp5.remove("userFunction1");
      cp5.remove("density1");
      cp5.remove("rotationAngle1");
      cp5.remove("selectedoperation");
      uicontainers.remove(1);
      addButton.setLabel("+ add");

      cp5.getController("folderDropdown0").setSize(114, 100);
      makeButton.setPosition(uicontainers.get(0).x+uicontainers.get(0).w, uicontainers.get(0).y - 20);
      movingNestBarrier = false;
    }
  }

  if (theEvent.isFrom(makeButton)) {
    String request = "http://127.0.0.1:3000/";

    if (uicontainers.size() > 1) {
      if (operation == WEAVING) request += "generate_woven?";
      else if (operation == TILING) request += "generate_tiling?";
    } else request += "generate_pattern?";

    String direction, folder, resolution, func1;
    for (int i = 0; i < uicontainers.size(); i++) {

      direction = String.valueOf(cp5.get(Knob.class, "rotationAngle"+i).getValue());
      int selected = int(cp5.get(ScrollableList.class, "folderDropdown"+i).getValue());
      String selectedFolder = cp5.get(ScrollableList.class, "folderDropdown"+i).getItem(selected).get("name").toString();

      folder = dataPath("") +"/" + selectedFolder;
      resolution = String.valueOf(int(cp5.getController("density"+i).getValue()));
      func1 = cp5.get(Textfield.class, "userFunction"+i).getText();
      try {
        func1 = URLEncoder.encode(func1, "UTF-8");
      }
      catch (Exception e) {
        e.printStackTrace();  // Print out the error if something weird happens
      }

      request += (i > 0? "&" : "")+"folder"+ (i > 0? i : "")+"="+folder;
      request += "&resolution"+(i > 0? i : "")+"="+resolution;
      request += "&rotation_angle"+(i > 0? i : "")+"="+direction;
      request += "&wave_function"+(i > 0? i : "")+"="+func1;
    }

    loadStrings(request);
    resetFileTimestamps();
  }

  if (theEvent.isFrom(cp5.get(Knob.class, "rotationAngle0"))&& uicontainers.size() > 1) {
    float slider0 = cp5.get(Knob.class, "rotationAngle0").getValue();
    float slider1 = slider0 + (slider0 > 0 ? -90 : 90);
    cp5.get(Knob.class, "rotationAngle1").setValue(slider1);
  }
}

void drawStateLabels() {
  fill(255);
  if (mode == PARALLAX) {
    if (freezeViewpoint) {
      text("viewing angle paused", 20, height*0.97);
    }

    text("scale factor: "+scale_factor*100+"%", width*0.75, height*0.97);
  }
}


float rescale_backplane(float w, float h, float fov_deg) {
  pg.smooth();
  pg.beginDraw();
  pg.rectMode(CENTER);
  pg.background(255);
  pg.blendMode(MULTIPLY);
  pg.pushMatrix();
  pg.noFill();
  pg.stroke(0);
  pg.strokeWeight(0.25);
  float fov = radians(fov_deg);
  boxD = round(ren_ppi*plane_distance);
  cameraZ = (height/2.0) / tan(fov/2.0);

  pg.perspective(fov, aspect, cameraZ/10.0, cameraZ*10.0);

  pg.translate(width/2, height/2, -distance*ren_ppi);

  // draw the back plane
  pg.pushMatrix();
  pg.translate(0, 0, -boxD);

  pg.rect(0, 0, w, h);

  pg.popMatrix();

  // draw the front plane
  pg.pushMatrix();

  pg.rect(0, 0, w, h);

  pg.popMatrix();
  pg.popMatrix();

  pg.save("planes.png");
  pg.endDraw();

  String s[] = loadStrings("http://127.0.0.1:3000/find_scale_factor");
  println(s[0]);

  return float(s[0]);
}

void interactionMode(int a) {
  mode = a;

  if (mode == PARALLAX) {
    planeDistSlider.show();
    viewDistSlider.show();
    fovSlider.show();
    scale_factor = rescale_backplane(2*ren_ppi, 2*ren_ppi, 11);

    back_plane_viewpoint.resize(round(back_plane.width*scale_factor), 0);
    back_plane_viewpoint.save("interlaced_scaled-"+scale_factor*100+".png");
  } else {
    planeDistSlider.hide();
    viewDistSlider.hide();
    fovSlider.hide();
  }
}

void selectedoperation(int a) {
  operation = a;
}

//void drawArrow(float x, float y, float size) {
//  line(x, y, x - size, y - size);
//  line(x, y, x - size, y + size);
//}

// Function to get the list of folders in a directory
List<String> listFolders(String path) {
  File dir = new File(path);
  List<String> folderNames = new ArrayList<String>();

  if (dir.isDirectory()) {
    File[] files = dir.listFiles();
    // Collect folder names
    for (File file : files) {
      if (file.isDirectory()) {
        folderNames.add(file.getName());
      }
    }
  } else {
    println("The path provided is not a directory: " + path);
  }

  return folderNames;
}
