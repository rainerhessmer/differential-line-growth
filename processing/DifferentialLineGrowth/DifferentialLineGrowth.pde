import processing.svg.*;
 
PGraphics hires;
Simulation simulation;
String fileNamePattern;
Boolean isPaused = false;

float scaling = Float.MAX_VALUE;

void setup() {
  //hires = createGraphics(2000, 2000, P2D);
  //hires.beginDraw();
  //background(255, 255, 255);
  //hires.endDraw();

  simulation = new Simulation();
  float radius = 400;
  int particleCount = 400;
  simulation.initParticles(radius, particleCount);

  size(1000, 1000, P2D);
  
  fileNamePattern = year() + nf(month(), 2) + nf(day(), 2) + "_" + nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2) + "_";
} 

void draw() {
  if (isPaused) {
    return;
  }
  //hires.beginDraw();
  simulation.step();
  
  drawSimulation(this.g);
  
  float scalingX = width / (simulation.maxX - simulation.minX);
  float scalingY = height / (simulation.maxY - simulation.minY);
  
  // Leave some room at the edges
  float newScaling = 0.90 * Math.min(scalingX, scalingY);
  scaling = Math.min(newScaling, scaling);
  simulation.draw(this.g, scaling);
  //hires.endDraw();
  
  /*
  PImage hiresImage = hires.get();
  
  float scalingFactor = 1.0 * width / hires.width;
  scale(scalingFactor);
  image(hiresImage, 0, 0);
  */
  
  //println(frameCount);
  //if (frameCount % 100 == 0) {
  //  saveFrame("_auto");
  //}
}

void drawSimulation(PGraphics graphics) {
  float scalingX = width / (simulation.maxX - simulation.minX);
  float scalingY = height / (simulation.maxY - simulation.minY);
  
  // Leave some room at the edges
  float newScaling = 0.90 * Math.min(scalingX, scalingY);
  scaling = Math.min(newScaling, scaling);
  
  simulation.draw(graphics, scaling);
}

void keyPressed(){
  if(key == ' '){
    saveFrame("_manual");
  } else if (key == 'p') {
    isPaused = !isPaused;
    println("isPaused: " + isPaused);
  } else if (key == 'h') {
    float radius = 100;
    int particleCount = 180;
    simulation.addHole(radius, particleCount);
  }
}

void saveFrame(String suffix) {
  String fileName = fileNamePattern + nf(frameCount, 4) + suffix + ".svg";
  println("Saving " + fileName + "  ...");
  
  PGraphics svgGraphics = createGraphics(this.g.width, this.g.height, SVG, fileName);
  
  svgGraphics.beginDraw();
  drawSimulation(svgGraphics);
  svgGraphics.endDraw();
  println("Done saving.");
}