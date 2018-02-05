class Simulation {
  private PVector center;
  private ArrayList<ArrayList<Particle>> particleLists = new ArrayList();
  private ArrayList<Particle> outerParticles = null;
  private ArrayList<Particle> innerParticles = null;
  private int iteration = 0;
  
  float minX = Float.MAX_VALUE;
  float maxX = Float.MIN_VALUE;
  float minY = Float.MAX_VALUE;
  float maxY = Float.MIN_VALUE;
 
  Simulation() {
    center = new PVector(0, 0);
  }
  
  void initParticles(float initRadius, int initParticleCount) {
    // initialize source nodes
    outerParticles = createParticles(this.center, initRadius, initParticleCount);
    particleLists.add(outerParticles);
    //particles.addAll(outerParticles);
  }
  
  private ArrayList<Particle> createParticles(PVector center, float initRadius, int initParticleCount) {
    ArrayList<Particle> particles = new ArrayList();

    float dTheta = 2 * (float)Math.PI / initParticleCount;
    Particle previousParticle = null;
    for (int i = 0; i < initParticleCount; i++) {
      // Arrange particle almost equidistantly in a circle
      // float jitter = 1 + ((float)Math.random() - 0.5) * 0.1;
      float theta = i * dTheta; // * jitter;
      PVector particleCenter = new PVector (
        center.x + (float)Math.cos(theta) * initRadius,
        center.y + (float)Math.sin(theta) * initRadius
      );
 
      Particle newParticle = new Particle(particleCenter);
      if (previousParticle != null) {
        previousParticle.addAfter(newParticle);
      }
      previousParticle = newParticle;
      particles.add(newParticle);
    }
    return particles;
  }
  
  void addHole(float initRadius, int initParticleCount) {
    innerParticles = createParticles(this.center, initRadius, initParticleCount);
    particleLists.add(innerParticles);
    //particles.addAll(innerParticles);
  }
 
  void step() {
    iteration++;
    println("STEP ", iteration);

    calcForces();
    reposition(0.1);
    //spawnUniformly(0.001);
    //spawnUniformlyInSection(0.001);
    //spawnCurvature(0.01, /* where max curvature */ true);
    spawnCurvature(0.001, /* where max curvature */ false);
    
    println("particle count: ", particleCount());
  }
  
  int particleCount() {
    int count = 0;
    for (ArrayList<Particle> particles : particleLists) {
      count += particles.size();
    }
    return count;
  }
   
  void calcForces() {
    ArrayList<Particle> allParticles;
    if (particleLists.size() == 1) {
      allParticles = particleLists.get(0);
    } else {
      allParticles = new ArrayList();
      for (ArrayList<Particle> particles : particleLists) {
        allParticles.addAll(particles);
      }
    }
    KdTree<Particle> kdTree = new KdTree(allParticles, distance2d, 2);
    for (Particle particle : allParticles) {
      particle.calcForces(kdTree, allParticles.size());
    }
    /*
    Particle firstParticle = outerParticles.get(0);
    Particle currentParticle = firstParticle;
    do {
      currentParticle.calcForces(kdTree, particles.size());
      currentParticle = currentParticle.next;
    } while (currentParticle != firstParticle);
    */
  }

  void reposition(float dt) {
    for (ArrayList<Particle> particles : particleLists) {
      for (Particle particle : particles) {
        particle.reposition(dt);
        adjustMinMax(particle);
      }
    }
  }
  
  private void adjustMinMax(Particle particle) {
    minX = Math.min(minX, particle.center.x);
    maxX = Math.max(minX, particle.center.x);
    minY = Math.min(minY, particle.center.y);
    maxY = Math.max(maxY, particle.center.y);
  }

  void spawnUniformly(float ratio) {
    // ratio is the ratio of edges to attempt spawning on.
   for (ArrayList<Particle> particles : particleLists) {
     spawnUniformly(particles, ratio);
   }
  }
  
  void spawnUniformly(List<Particle> particles, float ratio) {
    Particle firstParticle = particles.get(0);
    Particle currentParticle = firstParticle;
    do {
      if (Math.random() < ratio) {
        Particle newParticle = currentParticle.spawn();
        if (newParticle != null) {
          println("Adding particle");
          particles.add(newParticle);
          adjustMinMax(newParticle);
        }
      }
      currentParticle = currentParticle.next;
    } while (currentParticle != firstParticle);
  }

  void spawnUniformlyInSection(float ratio) {
    // ratio is the ratio of edges to attempt spawning on.
   for (ArrayList<Particle> particles : particleLists) {
     spawnUniformly(particles, ratio);
   }
  }
  
  void spawnUniformlyInSection(List<Particle> particles, float ratio) {
    int particleCount = particleCount();
    int startIndex = (int)Math.floor(Math.random() * particleCount);
    Particle currentParticle = particles.get(startIndex);
    int sectionLength = (int)(particleCount / 7);
    int i = 0;
    do {
      if (Math.random() < ratio) {
        Particle newParticle = currentParticle.spawn();
        if (newParticle != null) {
          println("Adding particle");
          particles.add(newParticle);
          adjustMinMax(newParticle);
        }
      }
      i++;
      currentParticle = currentParticle.next;
    } while (i < sectionLength);
  }

  void spawnCurvature(float ratio, boolean whereMaxCurvature) {
    // ratio is the ratio of edges to attempt spawning on.
   for (ArrayList<Particle> particles : particleLists) {
     spawnCurvature(particles, ratio, whereMaxCurvature);
   }
  }
  
  void spawnCurvature(List<Particle> particles, float ratio, boolean whereMaxCurvature) {
    Particle firstParticle = particles.get(0);
    Particle currentParticle = firstParticle;
    do {
        PVector toPrevious = PVector.sub(currentParticle.previous.center, currentParticle.center).normalize();
        PVector toNext = PVector.sub(currentParticle.next.center, currentParticle.center).normalize();
        float dotProduct = toPrevious.dot(toNext);
        // If the Dot Product is +1, the unit vectors are both pointing in the same direction.
        // If the Dot Product is zero, the unit vectors are perpendicular (at right-angles to each other).
        // If the Dot Product is -1, the unit vectors are pointing in opposite directions.
        float curvature = 0;
        if (whereMaxCurvature) {
          curvature = (float)Math.sqrt(1 + dotProduct);
        } else {
          curvature = dotProduct * dotProduct;
        }
        // println("dotProduct: ", dotProduct, ", curvature: ", curvature);

      if (Math.random() < ratio * curvature) {
        Particle newParticle = currentParticle.spawn();
        if (newParticle != null) {
          println("Adding particle");
          particles.add(newParticle);
          adjustMinMax(newParticle);
        }
      }
      currentParticle = currentParticle.next;
    } while (currentParticle != firstParticle);
  }

  void draw(PGraphics graphics, float scaling) {
    float centerX = graphics.width / 2; // - (maxX + minX) / 2;
    float centerY = graphics.height / 2; // - (maxY + minY) / 2;
    
    fillBackground(graphics);

    //graphics.beginDraw();
    
    //fill(255, 255, 255);
    PShape shape = graphics.createShape();
    shape.beginShape();
    shape.fill(0, 0, 0);

    Particle firstParticle = outerParticles.get(0);
    Particle currentParticle = firstParticle;
    //println(currentParticle.center.x, ", " , currentParticle.center.y);
    shape.vertex(centerX + scaling * currentParticle.center.x, centerY + scaling * currentParticle.center.y);
    do {
      currentParticle = currentParticle.next;
      //println(currentParticle.center.x, ", " , currentParticle.center.y);
      shape.vertex(centerX + scaling * currentParticle.center.x, centerY + scaling * currentParticle.center.y);
    } while (currentParticle != firstParticle);

    if (innerParticles != null) {
      // draw cutout
      addInteriorVertices(innerParticles, centerX, centerY, shape);
    }
    shape.endShape(CLOSE);
    //graphics.endDraw();
    graphics.shape(shape);
  }
  
  private void addInteriorVertices(ArrayList<Particle> particles, float centerX, float centerY, PShape shape) {
    shape.beginContour();
    Particle firstParticle = particles.get(0);
    Particle currentParticle = firstParticle;
    //println(currentParticle.center.x, ", " , currentParticle.center.y);
    shape.vertex(centerX + scaling * currentParticle.center.x, centerY + scaling * currentParticle.center.y);
    do {
      currentParticle = currentParticle.previous;
      //println(currentParticle.center.x, ", " , currentParticle.center.y);
      shape.vertex(centerX + scaling * currentParticle.center.x, centerY + scaling * currentParticle.center.y);
    } while (currentParticle != firstParticle);

    shape.endContour();
  }
  
  void fillBackground(PGraphics graphics) {
    graphics.background(255, 255, 255);
  }
}
