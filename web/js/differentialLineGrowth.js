// Inspired by and heavily borrowed from
//  http://www.codeplastic.com/2017/07/22/differential-line-growth-with-processing/
//  and http://inconvergent.net/generative/differential-line/
// 2018, Dr. Rainer Hessmer
// Licensed under the MIT license.

var canvas = document.getElementById('canvas');

var simulation;
var isPaused = false;

var smallestRadius = Number.MAX_VALUE;

function resizeCanvas() {
  canvas.width = window.innerWidth - 50;
  canvas.height = window.innerHeight - 50;

  isPaused = false;

  simulation = new DifferentialLine(canvas);
  simulation.initParticles(200, 150);
  //simulation.draw();
}

function calcDistance(point1, point2) {
  var dx = point1.x - point2.x;
  var dy = point1.y - point2.y
  return Math.sqrt(dx * dx + dy * dy);
}

class DifferentialLine {
  constructor(canvas) {
    this.canvas = canvas;
    this.ctx = canvas.getContext('2d');

    this.fillBackground();

    this.center = {
      x: 0.5 * canvas.width,
      y: 0.5 * canvas.height
    }

    this.particles = [];
    this.iteration = 0;
  }
  initParticles(initRadius, initParticleCount) {
    // initialize source nodes
    var dTheta = 2 * Math.PI / initParticleCount;
    var previousParticle = null;
    for (var i = 0; i < initParticleCount; i++) {
      // Arrange particle almost equidistantly in a circle
      var jitter = 1 + (Math.random() - 0.5) * 0.1;
      var theta = i * dTheta; // * jitter;
      var x = this.center.x + Math.cos(theta) * initRadius;
      var y = this.center.y + Math.sin(theta) * initRadius;

      var newParticle = new Particle(x, y, i);
      if (previousParticle == null) {
        this.firstParticle = newParticle;
      } else {
        previousParticle.addAfter(newParticle);
      }
      previousParticle = newParticle;
      this.particles.push(newParticle);
    }
    this.draw();
  }

  step() {
    //if (this.iteration == 21) {
    //  return;
    //}
    this.iteration++;

    this.calcForces();
    this.reposition(0.4);
    if (false) { //this.iteration % 5 == 0) {
      var index = Math.floor(Math.random() * this.particles.length);
      var newParticle = this.particles[index].spawn(this.particles.length);
      this.particles.push(newParticle);
      this.fillBackground();
      this.draw();
      newParticle.drawNeighbors(this.ctx);
      //this.firstParticle.next.next.drawNeighbors(this.ctx);
      //isPaused = true;
    } else {
      this.spawn(0.001);
      this.fillBackground();
      this.draw();
    }
  }

  calcForces() {
    this.tree = new kdTree(this.particles, calcDistance, ["x", "y"]);
    var currentParticle = this.firstParticle;
    do {
      currentParticle.calcForces(this.tree, this.particles.length);
      currentParticle = currentParticle.next;
    } while (currentParticle != this.firstParticle);
  }

  reposition(dt) {
    var currentParticle = this.firstParticle;
    do {
      currentParticle.reposition(dt);
      currentParticle = currentParticle.next;
    } while (currentParticle != this.firstParticle);
  }
  spawn(ratio) {
    // ratio is the ratio of edges to attempt spawning on.
    var currentParticle = this.firstParticle;
    do {
      if (Math.random() < ratio) {
        var newParticle = currentParticle.spawn(this.particles.length);
        if (newParticle != null) {
          this.particles.push(newParticle);
        }
      }
      currentParticle = currentParticle.next;
    } while (currentParticle != this.firstParticle);
  }

  draw() {
    var ctx = this.ctx;
    ctx.beginPath();
    var currentParticle = this.firstParticle;
    ctx.moveTo(currentParticle.x, currentParticle.y);
    do {
      // currentParticle.draw(this.ctx);
      currentParticle = currentParticle.next;
      ctx.lineTo(currentParticle.x, currentParticle.y);
    } while (currentParticle != this.firstParticle);

    ctx.closePath();
    ctx.fillStyle = 'red'; //'rgba(255, 255, 255, 1)'
    ctx.fill();
  }
  fillBackground() {
    // Fill to create background.
    this.ctx.fillStyle = '#FFFFFF';
    this.ctx.fillRect(0, 0, this.canvas.width, this.canvas.height);
  }
};

// A doubly linked circular list of particles.
class Particle {
  // The deired distance between direct neighbors.
  static get DESIRED_SEPARATION() { return 2.0; }

  // The constant k in Hooke's law describing the virtual spring between
  // direct neighbors.
  static get ATTRACTION_CONSTANT() { return 1.1; }

  static get REPULSION_CONSTANT() { return 1.0; }

  // The distance beyond which disconnected particles will ignore each other.
  static get TOO_FAR() { return 30.0; }

  // Drawing related
  static get RADIUS() { return 1; }
  static get CIRCLE_COLOR() { return '#000000'; }
  //static get CONNECTION_COLOR() { return 'rgba(0, 0, 0, 0.01)'; }
  static get CONNECTION_COLOR() { return 'rgba(0, 0, 0, 1)'; }

  // Creates a circular list of one.
  constructor(x, y, index) {
    this.x = x;
    this.y = y;
    this.index = index;
    this.previous = this;
    this.next = this;
  }

  // Adds the specified particle after this particle.
  addAfter(particle) {
    this.next.previous = particle;
    particle.next = this.next;

    particle.previous = this;
    this.next = particle;
  }

  // tree is the kdTree instance that provides efficient access to nearest
  // neighbors.
  calcForces(tree, particleCount) {
    //console.log(particleCount);
    // Initialize displacement force.
    this.dFx = 0;
    this.dFy = 0;

    // Find all particles that can influence this particle.
    var nearestParticleInfos = tree.nearest(this, particleCount, Particle.TOO_FAR);
    for (var i = 0; i < nearestParticleInfos.length; i++) {
      var particleInfo = nearestParticleInfos[i];
      var particle = particleInfo[0];
      var distance = particleInfo[1];

      if (particle === this) {
        // The particle does not create a force on itself
        continue;
      }

      var ndx = (particle.x - this.x) / distance;
      var ndy = (particle.y - this.y) / distance;
      if (particle === this.previous || particle === this.next) {
        // Direct neighbors try to reach their optimal distance.
        var deltaD = distance - Particle.DESIRED_SEPARATION;
        var dF = deltaD * Particle.ATTRACTION_CONSTANT;
        // If distance is greater than the desired distance then this particle
        // needs to move towards the other.
        //if (dF > 0) {
        //var dF2 = dF * dF;
        if (distance > Particle.DESIRED_SEPARATION) {
          // console.log(this.index + " too far by " + deltaD);
          this.dFx += ndx * dF;
          this.dFy += ndy * dF;
          //this.dFx += ndx * distance * Particle.ATTRACTION_CONSTANT;
          //this.dFy += ndy * distance * Particle.ATTRACTION_CONSTANT;
        } else {
          // At desired distance or closer.
          this.dFx += ndx * dF;
          this.dFy += ndy * dF;
        }
      } else {
        // Not a direct neighbor. Push away
        var dF = (Particle.TOO_FAR / distance - 1) * Particle.REPULSION_CONSTANT;
        this.dFx += -ndx * dF;
        this.dFy += -ndy * dF;
      }
    }
  }
  reposition(dt) {
    this.x += dt * this.dFx;
    this.y += dt * this.dFy;
  }
  spawn(particleIndex) {
    // Potentially spawn a new particle between this and the next.
    var distance = calcDistance(this, this.next);
    if (distance <= Particle.DESIRED_SEPARATION) {
      console.log("too close to spawn.");
      return null;
    }

    var newParticle = new Particle(
      (this.x + this.next.x) / 2,
      (this.y + this.next.y) / 2,
      particleIndex
    );
    this.addAfter(newParticle);
    return newParticle;
  }

  draw(ctx) {
    //this.drawCircle(ctx, Particle.RADIUS, Particle.CIRCLE_COLOR);
    this.drawConnection(ctx);
  }

  drawCircle(ctx, radius, color) {
    ctx.beginPath();
    ctx.arc(this.x, this.y, radius, 0, 2 * Math.PI, false);
    // ctx.arc(0, 0, Particle.RADIUS, 0, 2 * Math.PI, false);
    ctx.lineWidth = 1;
    var value = this.index * 25;
    // ctx.strokeStyle = "rgb(" + value + ", " + value + ", " + value + ")"; // Particle.CIRCLE_COLOR;
    ctx.strokeStyle = color;
    ctx.stroke();
  }
  drawConnection(ctx) {
    ctx.beginPath();
    ctx.moveTo(this.x, this.y);
    ctx.lineWidth = 1;
    //ctx.lineCap = 'round';
    ctx.strokeStyle = Particle.CONNECTION_COLOR;
    ctx.lineTo(this.next.x, this.next.y);
    ctx.stroke();
  }
  drawNeighbors(ctx) {
    var radius = 3 * Particle.RADIUS;
    this.next.drawCircle(ctx, radius, '#FF0000');
    this.previous.drawCircle(ctx, radius, '#00FF00');
  }
}

function drawFrame() {
  if (!isPaused) {
    simulation.step();
  }
  window.setTimeout(drawFrame, 1);
};

function onNewFrame() {
  if (!isPaused ) {
    simulation.step();
  }
  requestAnimationFrame(onNewFrame);
}

//window.addEventListener('resize', resizeCanvas, false);

window.onkeydown = function(evt) {
    evt = evt || window.event;
    if (evt.key == " ") {
      // toggle isPaused
      isPaused = !isPaused;
    }
};

resizeCanvas();
requestAnimationFrame(onNewFrame);
//drawFrame();
