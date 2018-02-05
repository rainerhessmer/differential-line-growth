// Implementation of KD Tree based on the code
// https://github.com/ubilabs/kd-tree-javascript
// 
// Ported to processing by Dr. Rainer Hessmer, 2018
//
// MIT License <http://www.opensource.org/licenses/mit-license.php>

import java.util.List;
import java.util.ArrayList;
import java.util.Comparator;

public interface Point {
  public double get(int i);
}

public interface Metric {
  double distance(Point p1, Point p2);
}

public static final Metric distance2d = new Metric() {
  public double distance(Point p1, Point p2) {
    double dx = p1.get(0) - p2.get(0);
    double dy = p1.get(1) - p2.get(1);
    
    return Math.sqrt(dx * dx + dy * dy);
  }
};

public static Comparator<Point> createComparerForDimension(final int dim) {
  return new Comparator<Point>() {
    private int dimension = dim;
    public int compare(Point a, Point b) {
      return Double.compare(a.get(dimension), b.get(dimension));
    }
  };
};

public class Node<T extends Point> {
  private T point;
  private Node left;
  private Node right;
  private Node parent;
  private int dimension;

  public Node(T point, int dimension, Node parent) {
    this.point = point;
    this.dimension = dimension;
    this.parent = parent;
  }
}

public class ElementPlusDistance<T> {
  T element;
  double distance;
  
  ElementPlusDistance(T element, double distance) {
    this.element = element;
    this.distance = distance;
  }
}

public class KdTree<T extends Point> {
  private Metric metric;
  private int dimensionCount;
  private Node root;
  
  public KdTree(List<T> points, Metric metric, int dimensionCount) {
    this.metric = metric;
    this.dimensionCount = dimensionCount;
    
    this.root = buildTree(points, 0, null);
  }
  
  private Node buildTree(List<T> points, int depth, Node parent) {
   int dim = depth % dimensionCount;
 
    if (points.isEmpty()) {
      return null;
    }
    if (points.size() == 1) {
      return new Node(points.get(0), dim, parent);
    }

    Comparator comparator = createComparerForDimension(dim);
    points.sort(comparator);

    int median = (int)Math.floor(points.size() / 2);
    Node node = new Node(points.get(median), dim, parent);
    node.left = buildTree(points.subList(0, median), depth + 1, node);
    node.right = buildTree(points.subList(median + 1, points.size()), depth + 1, node);

    return node;
  }
  
  public void insert(T point) {
    Node insertPosition = search(point, this.root, null);
 
    if (insertPosition == null) {
      this.root = new Node(point, 0, null);
      return;
    }

    Node newNode = new Node(point, (insertPosition.dimension + 1) % dimensionCount, insertPosition);
    int dimension = insertPosition.dimension;

    if (point.get(dimension) < insertPosition.point.get(dimension)) {
      insertPosition.left = newNode;
    } else {
      insertPosition.right = newNode;
    }
  }
  
  private Node search(Point point, Node node, Node parent) {
    if (node == null) {
      return parent;
    }

    if (point.get(node.dimension) < node.point.get(node.dimension)) {
      return search(point, node.left, node);
    } else {
      return search(point, node.right, node);
    }
  }

/* TODO: Port remove functionality.

    this.remove = function (point) {
      var node;

      function nodeSearch(node) {
        if (node === null) {
          return null;
        }

        if (node.obj === point) {
          return node;
        }

        var dimension = dimensions[node.dimension];

        if (point[dimension] < node.obj[dimension]) {
          return nodeSearch(node.left, node);
        } else {
          return nodeSearch(node.right, node);
        }
      }

      function removeNode(node) {
        var nextNode,
          nextObj,
          pDimension;

        function findMin(node, dim) {
          var dimension,
            own,
            left,
            right,
            min;

          if (node === null) {
            return null;
          }

          dimension = dimensions[dim];

          if (node.dimension === dim) {
            if (node.left !== null) {
              return findMin(node.left, dim);
            }
            return node;
          }

          own = node.obj[dimension];
          left = findMin(node.left, dim);
          right = findMin(node.right, dim);
          min = node;

          if (left !== null && left.obj[dimension] < own) {
            min = left;
          }
          if (right !== null && right.obj[dimension] < min.obj[dimension]) {
            min = right;
          }
          return min;
        }

        if (node.left === null && node.right === null) {
          if (node.parent === null) {
            self.root = null;
            return;
          }

          pDimension = dimensions[node.parent.dimension];

          if (node.obj[pDimension] < node.parent.obj[pDimension]) {
            node.parent.left = null;
          } else {
            node.parent.right = null;
          }
          return;
        }

        // If the right subtree is not empty, swap with the minimum element on the
        // node's dimension. If it is empty, we swap the left and right subtrees and
        // do the same.
        if (node.right !== null) {
          nextNode = findMin(node.right, node.dimension);
          nextObj = nextNode.obj;
          removeNode(nextNode);
          node.obj = nextObj;
        } else {
          nextNode = findMin(node.left, node.dimension);
          nextObj = nextNode.obj;
          removeNode(nextNode);
          node.right = node.left;
          node.left = null;
          node.obj = nextObj;
        }

      }

      node = nodeSearch(self.root);

      if (node === null) { return; }

      removeNode(node);
    };
    
    public interface Scorer<T> {
  double score(T element);
}

*/

  class Searcher {
    private Point point;
    private int maxNodes;
    private double maxDistance;
    private Metric metric;
    int dimensionCount;
    
    private BinaryHeap<ElementPlusDistance<Node<T>>> bestNodes;
    
    Searcher(T point, int maxNodes, double maxDistance, Metric metric, int dimensionCount) {
      this.point = point;
      this.maxNodes = maxNodes;
      this.maxDistance = maxDistance;
      this.metric = metric;
      this.dimensionCount = dimensionCount;
    }
    
    List<ElementPlusDistance<T>> search() {
      Scorer<ElementPlusDistance<T>> scorer = new Scorer<ElementPlusDistance<T>>() {
        @Override
        public double score(ElementPlusDistance<T> value) {
          return -value.distance;
        }
      };
      
      bestNodes = new BinaryHeap(scorer);
      
      if (maxDistance >= 0) {
        for (int i = 0; i < maxNodes; i += 1) {
          bestNodes.push(new ElementPlusDistance(null, maxDistance));
        }
      }
      
      if (root != null) {
        nearestSearch(root);
      }
      
      List<ElementPlusDistance<T>> result = new ArrayList();
      for (int i = 0; i < Math.min(maxNodes, bestNodes.content.size()); i++) {
        ElementPlusDistance<Node<T>> nodePlusDistance = bestNodes.content.get(i);
        if (nodePlusDistance.element != null) {
          result.add(new ElementPlusDistance<T>(nodePlusDistance.element.point, nodePlusDistance.distance));
        }
      }
      return result;
    }
    
    private void saveNode(Node<T> node, double distance) {
      ElementPlusDistance<Node<T>> entry = new ElementPlusDistance(node, distance);
      bestNodes.push(entry);
      if (bestNodes.size() > maxNodes) {
        bestNodes.pop();
      }
    }
    
    class PointImpl implements Point {
      double[] dimensions;
      
      PointImpl(int dimensionCount) {
        this.dimensions = new double[dimensionCount];
      }
      
      @Override
      public double get(int i) {
        return dimensions[i];
      }
    }
     
    private void nearestSearch(Node node) {
      double ownDistance = metric.distance(point, node.point);
      PointImpl linearPoint = new PointImpl(dimensionCount);

      for (int i = 0; i < dimensionCount; i++) {
        if (i == node.dimension) {
          linearPoint.dimensions[i] = point.get(i);
        } else {
          linearPoint.dimensions[i] = node.point.get(i);
        }
      }

      
      double linearDistance = metric.distance(linearPoint, node.point);

      if (node.right == null && node.left == null) {
        if (bestNodes.size() < maxNodes || ownDistance < bestNodes.peek().distance) {
          saveNode(node, ownDistance);
        }
        return;
      }

      Node bestChild;
      int dimension = node.dimension;
      if (node.right == null) {
        bestChild = node.left;
      } else if (node.left == null) {
        bestChild = node.right;
      } else {
        if (point.get(dimension) < node.point.get(dimension)) {
          bestChild = node.left;
        } else {
          bestChild = node.right;
        }
      }

      nearestSearch(bestChild);

      if (bestNodes.size() < maxNodes || ownDistance < bestNodes.peek().distance) {
        saveNode(node, ownDistance);
      }

      Node otherChild;
      if (bestNodes.size() < maxNodes || Math.abs(linearDistance) < bestNodes.peek().distance) {
        if (bestChild == node.left) {
          otherChild = node.right;
        } else {
          otherChild = node.left;
        }
        if (otherChild != null) {
          nearestSearch(otherChild);
        }
      }
    }
  }
  
  public List<ElementPlusDistance<T>> nearest(T point, int maxNodes, double maxDistance) {
    Searcher searcher = new Searcher(point, maxNodes, maxDistance, metric, dimensionCount);
    return searcher.search();
  }
     
  public double balanceFactor() {
    return height(root) / (Math.log(count(root)) / Math.log(2));
  }
  
  private int height(Node node) {
    if (node == null) {
      return 0;
    } else {
      return Math.max(height(node.left), height(node.right)) + 1;
    }
  }
  
  private int count(Node node) {
    if (node == null) {
      return 0;
    }
    return count(node.left) + count(node.right) + 1;
  }
}


// Binary heap implementation from:
// http://eloquentjavascript.net/appendix2.html

public interface Scorer<T> {
  double score(T element);
}

public class BinaryHeap<T> {
  private ArrayList<T> content = new ArrayList();
  private Scorer scorer;
  
  public BinaryHeap(Scorer scorer) {
    this.scorer = scorer;
  }
  
  public void push(T element) {
    // Add the new element to the end of the array.
    content.add(element);
    // Allow it to bubble up.
    bubbleUp(content.size() - 1);
  }
  
  public T pop() {
    // Store the first element so we can return it later.
    T result = content.get(0);
    // Get the element at the end of the array.
    T end = content.remove(content.size() - 1);
    // If there are any elements left, put the end element at the
    // start, and let it sink down.
    if (!content.isEmpty()) {
      content.set(0, end);
      sinkDown(0);
    }
    return result;
  }
  
  public T peek() {
    return content.get(0);
  }
  
  public int size() {
    return content.size();
  }
  
  public boolean remove(T element) {
    int size = content.size();
    // To remove a value, we must search through the array to find it.
    for (int i = 0; i < size; i++) {
      if (content.get(i) == element) {
        // When it is found, the process seen in 'pop' is repeated to fill up the hole.
        T end = content.remove(content.size() - 1);
        if (i != size - 1) {
          content.set(i, end);
          if (scorer.score(end) < scorer.score(element)) {
            this.bubbleUp(i);
          } else {
            this.sinkDown(i);
          }
        }
        return true;
      }
    }
    // element wasn't found.
    return false;
  }

  private void bubbleUp(int n) {
    // Fetch the element that has to be moved.
    T element = content.get(n);
    // When at 0, an element can not go up any further.
    while (n > 0) {
      // Compute the parent element's index, and fetch it.
      int parentN = (int)Math.floor((n + 1) / 2) - 1;
       T parent = content.get(parentN);
      // Swap the elements if the parent is greater.
      if (scorer.score(element) < scorer.score(parent)) {
        content.set(parentN, element);
        content.set(n, parent);
        // Update 'n' to continue at the new position.
        n = parentN;
      }
      // Found a parent that is less, no need to move it further.
      else {
        break;
      }
    }
  }

  private void sinkDown(int n) {
    // Look up the target element and its score.
    int length = content.size();
    T element = content.get(n);
    double elemScore = scorer.score(element);

    while(true) {
      // Compute the indices of the child elements.
      int child2N = (n + 1) * 2;
      int child1N = child2N - 1;
      // This is used to store the new position of the element, if any.
      int swap = -1;
      double child1Score = -1;
      // If the first child exists (is inside the array)...
      if (child1N < length) {
        // Look it up and compute its score.
        T child1 = content.get(child1N);
        child1Score = scorer.score(child1);
        // If the score is less than our element's, we need to swap.
        if (child1Score < elemScore)
          swap = child1N;
      }
      // Do the same checks for the other child.
      if (child2N < length) {
        T child2 = content.get(child2N);
        double child2Score = scorer.score(child2);
        if (child2Score < (swap == -1 ? elemScore : child1Score)){
          swap = child2N;
        }
      }

      // If the element needs to be moved, swap it, and continue.
      if (swap != -1) {
        content.set(n, content.get(swap));
        content.set(swap, element);
        n = swap;
      }
      // Otherwise, we are done.
      else {
        break;
      }
    }
  }
}