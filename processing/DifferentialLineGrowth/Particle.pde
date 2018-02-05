int particleIndex = 0;

// A doubly linked circular list of particles.
class Particle implements Point {
  // The deired distance between direct neighbors.
  final static float DESIRED_SEPARATION = 2.0;

  // The constant k in Hooke's law describing the virtual spring between
  // direct neighbors.
  final static float ATTRACTION_CONSTANT = 1.1;

  final static float REPULSION_CONSTANT = 1.0;

  // The distance beyond which disconnected particles will ignore each other.
  final static float TOO_FAR = 200.0;

  // Drawing related
  final static float RADIUS = 1;
  final color CIRCLE_COLOR = color(0, 0, 0);
  //static get CONNECTION_COLOR() { return 'rgba(0, 0, 0, 0.01)'; }
  final color CONNECTION_COLOR = color(0, 0, 0);

  private PVector center;
  private Particle previous;
  private Particle next;
  private int index;
  
  private float dFx = 0;
  private float dFy = 0;

  Particle(PVector center) {
    this.center = center;
    this.index = particleIndex++; 
    
    this.previous = this;
    this.next = this;
  }
  
  @Override
  public double get(int i) {
    switch (i) {
      case 0:
        return center.x;
      case 1:
        return center.y;
      default:
        println("Error");
        return 0;
    }
  }

  // Adds the specified particle after this particle.
  void addAfter(Particle particle) {
    this.next.previous = particle;
    particle.next = this.next;

    particle.previous = this;
    this.next = particle;
  }

  // tree is the kdTree instance that provides efficient access to nearest
  // neighbors.
  void calcForces(KdTree<Particle> kdTree, int particleCount) {
    //console.log(particleCount);
    // Initialize displacement force.
    this.dFx = 0;
    this.dFy = 0;

    // Find all particles that can influence this particle.
    List<ElementPlusDistance<Particle>> nearestList = kdTree.nearest(this, particleCount, TOO_FAR);
    for (ElementPlusDistance<Particle> nearest : nearestList) {
      Particle particle = nearest.element;
      float distance = (float)nearest.distance;

      if (particle == this) {
        // The particle does not create a force on itself
        continue;
      }

      float ndx = (particle.center.x - this.center.x) / distance;
      if (Float.isNaN(ndx)) {
        println("NaN");
      }

      float ndy = (particle.center.y - this.center.y) / distance;
      if (particle == this.previous || particle == this.next) {
        // Direct neighbors try to reach their optimal distance.
        float deltaD = distance - DESIRED_SEPARATION;
        float dF = deltaD * ATTRACTION_CONSTANT;
        // If distance is greater than the desired distance then this particle
        // needs to move towards the other.
        //if (dF > 0) {
        //var dF2 = dF * dF;
        if (distance > DESIRED_SEPARATION) {
          // console.log(this.index + " too far by " + deltaD);
          this.dFx += ndx * dF;
          this.dFy += ndy * dF;
          //this.dFx += ndx * distance * Particle.ATTRACTION_CONSTANT;
          //this.dFy += ndy * distance * Particle.ATTRACTION_CONSTANT;
        } else {
          // At desired distance or closer.
          this.dFx += ndx * dF * dF;
          this.dFy += ndy * dF * dF;
        }
      } else {
        // Not a direct neighbor. Push away
        float dF = (TOO_FAR / distance - 1) * REPULSION_CONSTANT;
        this.dFx += -ndx * dF;
        this.dFy += -ndy * dF;
      }
    }
  }
  
  void reposition(float dt) {
    this.center.x += dt * this.dFx;
    this.center.y += dt * this.dFy;
  }
  
  Particle spawn() {
    // Potentially spawn a new particle between this and the next.
    float distance = this.center.dist(this.next.center);
    if (distance <= DESIRED_SEPARATION) {
      println("too close to spawn.");
      return null;
    }

    PVector newCenter = this.center.copy().add(this.next.center).mult(0.5);
    Particle newParticle = new Particle(newCenter);
   
    addAfter(newParticle);
    return newParticle;
  }

  void draw(PGraphics graphics) {
    //this.drawCircle(ctx, Particle.RADIUS, Particle.CIRCLE_COLOR);
    drawConnection(graphics);
  }

  void drawCircle(PGraphics graphics, float radius, color c) {
     //graphics.stroke(0, 0, 0);
    //graphics.strokeWeight(1);
    graphics.stroke(c);
    //graphics.strokeWeight(1);
    graphics.strokeWeight(0);
    graphics.fill(0);
    graphics.ellipse(center.x, center.y, 2 * radius, 2 * radius);
   }
 
  void drawConnection(PGraphics graphics) {
    graphics.strokeWeight(1);
    graphics.line(center.x, center.y, next.center.x, next.center.y);
  }
  
  void drawNeighbors(PGraphics graphics) {
    float radius = 3 * RADIUS;
    this.next.drawCircle(graphics, radius, color(255, 0, 0));
    this.previous.drawCircle(graphics, radius, color(0, 255, 0));
  }
}
