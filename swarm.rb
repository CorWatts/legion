require 'rubygems'
require 'gosu'

$WIDTH = 700 # width of field
$HEIGHT = 700 # height of field
$NUMOFCRITTERS = 25 # number of critters to generate

# CREATURE SPEEDS
$MAXSPEED = 1 # max speed of each critter upon generation
$NOMINALSPEED = 3 # the speed each critter will try to reach

# CREATURE SENSES
$FIELDOFVIEW = (0.3333 * 360).round # (120 degrees) the field of vision the critter has in front of them
$NEIGHBORRADIUS = 70 # how many pixels away each creature can see

# WEIGHTS
$COHESIONWEIGHT = 0.1 # for swarm cohesion
$SEPARATIONWEIGHT = 1 # for swarm separation
$EDGESTRENGTHWEIGHT = 5 # for repelling from walls
$NOMINALSPEEDWEIGHT = 1 # for reaching the nominal speed
$ALIGNMENTWEIGHT = 1  # for aligning the critter with neighbors

  # a position
  class Posn
    attr_accessor :x, :y
    
    def initialize(x, y)
      @x = x
      @y = y
    end
    
    # checks if posn is all zeros
    def zero?
      (@x == 0 && @y == 0) ? true : false
    end
    
    # prints out posn values
    def print
        puts "(#{@x}, #{@y})"
    end
  end
            

  class Critter
    def initialize(window)
      @image = Gosu::Image.new(window, "bug.resized.png", true)
      @radius = 5
      @loc = Posn.new(rand($WIDTH), rand($HEIGHT))
      # can be in a range from -MAXSPEED to +MAXSPEED
      @speed = Posn.new(rand(2 * $MAXSPEED) - $MAXSPEED, rand(2 * $MAXSPEED) - $MAXSPEED)
      @angle = calculate_angle(Posn.new(0, 0), @speed)
      @critterList
      @neighborList
    end
    
    def draw
        @image.draw_rot(@loc.x, @loc.y, @radius, @angle)
    end
    
    def move(critterList)
        @critterList = critterList
        @neighborList = get_visible_neighbors
        adjustmentVector = add_adjustment_vectors
        @speed.x = adjustmentVector.x + @speed.x
        @speed.y = adjustmentVector.y + @speed.y
        @loc.x = @loc.x + @speed.x
        @loc.y = @loc.y + @speed.y
        @loc.x = @loc.x % $WIDTH
        @loc.y = @loc.y % $HEIGHT
        @angle = calculate_angle(Posn.new(0, 0), @speed)
    end
    
    # location
    # returns posn
    # gets the position of the critter
    def location
      @loc
    end
    
    # speed
    # returns posn
    # gets the speed of the critter
    def speed
      @speed
    end
    
    # get_visible_neighbors
    # returns array of critters
    # gets the critter's visible neighbors
    # INCLUDES THE CRITTER'S SELF
    def get_visible_neighbors
      neighbors = Array.new
      @critterList.each { |critter|
        neighborPosn = critter.location
        if(visible?(neighborPosn))
          neighbors.push(critter)
        end  
      }
      if(neighbors.length > 1)
        puts neighbors.length
      end
      neighbors
    end
      
    # calculate_angle(int, int)
    # returns int (an angle from 0-360)
    # 0,0 starts at top-left and both increase going to bottom-right
    # for determing critter angle, loc is (0, 0), for wall or neighbor angle, loc is @loc
    def calculate_angle(loc, other)
      # we need to compensate for y being reversed on the grid (change to a normal cartesian grid)
      locY = loc.y * -1
      locX = loc.x
      otherY = other.y * -1
      otherX = other.x
      # normally it's (speedy, speedx) but that gives us 0 degrees at the positive x axis.
      # to rotate 0 degrees to the positive y axis, switch the arguments
      radians = Math.atan2(otherX - locX, otherY - locY) 
      degrees = radians * 180 / Math::PI
      # compensate for negative values
      if(degrees < 0)
        degrees += 360 
      end 
       
      degrees.round
    end 

    # visible?(posn)
    # returns bool
    # calculate if another point is visible? -- must be in field of view and close enough
    def visible?(point)
        # distance to other point (hypotenuse)
        distance = Math.hypot(@loc.x - point.x, @loc.y - point.y)
        # the angleOffOfForward is from @angle
        # calculate the specific angle off of @angle
        angleOffOfForward = (calculate_angle(@loc, point) - @angle)
        while(angleOffOfForward < -180) do angleOffOfForward += 360 end
        while(angleOffOfForward > 180) do angleOffOfForward -= 360 end
        
        if((distance <= $NEIGHBORRADIUS) && (angleOffOfForward.abs <= (0.5 * $FIELDOFVIEW)))
          #puts "wall visible"
          true
        else
          #puts "wall not visible"
          false
        end
    end

    # normalize_vector(posn)
    # returns posn
    # scales the vector down to a small fraction so weighing each vector is easier
    def normalize_vector(vector)
      x = vector.x
      y = vector.y
      magnitude = Math.hypot(x, y) # magnitude of vector
      newX = x / magnitude
      newY = y / magnitude
      Posn.new(newX, newY)
    end
      
    # get_repulsion_factor(posn, posn)
    # returns posn
    # takes in a point and uses the critter's current location to calculate a repulsive force
    def get_repulsion_factor(loc, other)
      # watch out for dividing by zero
      xdiff = other.x - loc.x
      ydiff = other.y - loc.y
      if(xdiff != 0)
        repulsiveX = -1 / ((xdiff) ** 2.0)
      else
        repulsiveX = 0
      end
      
      if(ydiff != 0)
        repulsiveY = -1 / ((ydiff) ** 2.0)
      else
        repulsiveY = 0
      end

      # if *diff is negative initially, repulsion must be positive so grab absolute value
      if(xdiff < 0)
        repulsiveX = repulsiveX.abs
      end
      if(ydiff < 0)
        repulsiveY = repulsiveY.abs
      end
      
      Posn.new(repulsiveX, repulsiveY)
    end
    
    # find_average_neighbor
    # returns Posn
    # calculates the average position of every neighbor
    def find_average_neighbor
      # if there are no neighbors, no change
      if(@neighborList.length < 2)
        return Posn.new(0, 0)
      end
      
      avgPosnX = avgPosnY = 0
      @neighborList.each { |neighbor|
        avgPosnX += neighbor.location.x
        avgPosnY += neighbor.location.y
      }
      
      # subtract current location from avg
      avgPosnX -= @loc.x
      avgPosnY -= @loc.y
      
      totalX = avgPosnX / (@neighborList.length - 1)
      totalY = avgPosnY / (@neighborList.length - 1)
      Posn.new(totalX, totalY)
    end
    
    # add_posns(array)
    # returns posn
    # adds together an array of posns
    def add_posns(posnArray)
      x = y = 0
      if(posnArray.length > 0)
        for i in 0...posnArray.length
          x += posnArray[i].x
          y += posnArray[i].y
        end
        Posn.new(x, y)
      else
        Posn.new(0, 0)
      end
    end
    
    # average_posns(array)
    # returns posn
    # averages together an array of posns.  If ignoreZeros is true, then posns like (0, 0)
    # will not be taken into the average.  If false, they will be.
    def average_posns(posnArray, ignoreZeros = true, deletePosn = false, posnToDelete = false)
      x = y =  0
      zeroCount = 0
      if(posnArray.length > 0)
        for i in 0...posnArray.length
          x += posnArray[i].x
          y += posnArray[i].y
          if(posnArray[i].zero?) then zeroCount += 1 end
        end
        # avoid dividing by zero
        if(posnArray.length - zeroCount == 0)
          Posn.new(0, 0)
        end
        puts "before subtraction: (#{x}, #{y})"
        if(deletePosn == true && posnToDelete != false)
          x = x - posnToDelete.x
          y = y - posnToDelete.y
        end
        puts "after subtraction: (#{x}, #{y})"

        if(ignoreZeros)
          x = x / (posnArray.length - zeroCount)
          y = y / (posnArray.length - zeroCount)
        else
          x = x / posnArray.length
          y = y / posnArray.length
        end
        
        Posn.new(x.round, y.round)
      else
        Posn.new(0, 0)
      end
    end
    
    # calculate_vector
    # returns Posn
    # calculates the vector between two positions
    def calculate_vector(posn1, posn2)
      diffX = posn2.x - posn1.x
      diffY = posn2.y - posn1.y
      Posn.new(diffX, diffY)
    end
    
    # get_nominal_speed_vector
    # returns posn
    # changes current speed to nominal speed
    def get_nominal_speed_vector
      speedX = @speed.x
      speedY = @speed.y
      
      if(speedX != $NOMINALSPEED && speedY != $NOMINALSPEED)
      
        if(speedX >= 0)
          newSpeedX = $NOMINALSPEED - speedX
        else
          newSpeedX = -$NOMINALSPEED - speedX
        end
        if(speedY >= 0)
          newSpeedY = $NOMINALSPEED - speedY
        else
          newSpeedY = -$NOMINALSPEED - speedY
        end
        Posn.new(newSpeedX, newSpeedY)
        
      elsif(speedX.abs != $NOMINALSPEED)
      
        if(speedX >= 0)
          newSpeedX = $NOMINALSPEED - speedX
        else
          newSpeedX = -$NOMINALSPEED - speedX
        end
        Posn.new(newSpeedX, 0)
        
      elsif(speedY.abs != $NOMINALSPEED)
      
        if(speedY >= 0)
          newSpeedY = $NOMINALSPEED - speedY
        else
          newSpeedY = -$NOMINALSPEED - speedY
        end
        Posn.new(0, newSpeedY)
        
      else 
        Posn.new(0, 0)
      end
    end
    
    # get_edge_avoidance_vector
    # returns posn( a vector)
    # if the critter is near an edge, this vector will direct them away from it
    def get_edge_avoidance_vector
      edgeVectors = Array.new
      leftEdgePosn = Posn.new(0, @loc.y)
      topEdgePosn = Posn.new(@loc.x, 0)
      rightEdgePosn = Posn.new($WIDTH, @loc.y)
      bottomEdgePosn = Posn.new(@loc.x, $HEIGHT)
      
      if(visible?(topEdgePosn))
        edgeVectors.push(get_repulsion_factor(@loc, topEdgePosn))
      end
      if(visible?(rightEdgePosn))
        edgeVectors.push(get_repulsion_factor(@loc, rightEdgePosn))
      end
      if(visible?(bottomEdgePosn))
        edgeVectors.push(get_repulsion_factor(@loc, bottomEdgePosn))
      end
      if(visible?(leftEdgePosn))
        edgeVectors.push(get_repulsion_factor(@loc, leftEdgePosn))
      end
      if(edgeVectors.length > 0)
        add_posns(edgeVectors)
      else
        Posn.new(0, 0)
      end
    end
    
    # get_alignment_vector
    # returns Posn
    # calculates the average speed vector of all neighbors
    def get_alignment_vector
      # if there are no neighbors, no alignment vector change
      if(@neighborList.length < 2)
        return Posn.new(0, 0)
      end
        
      neighborSpeedArray = Array.new
      neighborX = neighborY = 0
      @neighborList.each { |neighbor|
        neighborX += neighbor.speed.x
        neighborY += neighbor.speed.y
      }
      neighborAvgX = (neighborX - @speed.x) / (@neighborList.length - 1)
      neighborAvgY = (neighborY - @speed.y) / (@neighborList.length - 1)
      totalX = neighborAvgX - @speed.x
      totalY = neighborAvgY - @speed.y
      Posn.new(totalX, totalY)
    end
    
    # getSeparationVector
    # returns Posn
    # calculates the average position of neighbors and generates a repulsive force
    def getSeparationVector
    # if there are no neighbors, no separation vector change
      if(@neighborList.length < 2)
        Posn.new(0, 0)
      end
      
      get_repulsion_factor(@loc, find_average_neighbor) # return total separation vector
    end
    
    # get_cohesion_vector
    # returns posn
    # calculates the average position of neighbors and generates an attractive force
    def get_cohesion_vector
    # if there are no neighbors, no cohesion vector change
      if(@neighborList.length < 2)
        Posn.new(0, 0)
      end
      
      # return the vector that points to the avg neighbor's position'
      calculate_vector(@loc, find_average_neighbor)
    end
    
    # construct_edge_vector
    # returns posn
    # calculates the edge adjustment vector, normalizes it, and adds the weight
    def construct_edge_vector
      edgeVector = get_edge_avoidance_vector
      if(edgeVector.zero?)
        edgeVector
      else
        normalizedEdgeVector = normalize_vector(edgeVector)
        totalX = ($EDGESTRENGTHWEIGHT * normalizedEdgeVector.x)
        totalY = ($EDGESTRENGTHWEIGHT * normalizedEdgeVector.y)
        Posn.new(totalX, totalY)
      end
    end 
    
    # construct_nominal_speed_vector
    # returns posn
    # constructs the nominal speed vector, normalizes it, and adds the weight
    def construct_nominal_speed_vector
      speedVector = get_nominal_speed_vector
      if(speedVector.zero?)
        speedVector
      else
        normalizedSpeedVector = normalize_vector(speedVector)
        totalX = $NOMINALSPEEDWEIGHT * normalizedSpeedVector.x
        totalY = $NOMINALSPEEDWEIGHT * normalizedSpeedVector.y
        Posn.new(totalX, totalY)
      end
    end  
    
    # construct_alignment_vector
    # returns posn
    # constructs the alignment vector, normalizes it, and adds the weight
    def construct_alignment_vector
      alignmentVector = get_alignment_vector
      if(alignmentVector.zero?)
        alignmentVector
      else
        normalizedAlignmentVector = normalize_vector(alignmentVector)
        totalX = $ALIGNMENTWEIGHT * normalizedAlignmentVector.x
        totalY = $ALIGNMENTWEIGHT * normalizedAlignmentVector.y
        Posn.new(totalX, totalY)
      end
    end
    
    # construct_separation_vector
    # returns posn
    # constructs the alignment vector, normalizes it, and adds the weight
    def construct_separation_vector
      separationVector = getSeparationVector
      if(separationVector.zero?)
        separationVector
      else
        normalizedSeparationVector = normalize_vector(separationVector)
        totalX = $SEPARATIONWEIGHT * normalizedSeparationVector.x
        totalY = $SEPARATIONWEIGHT * normalizedSeparationVector.y
        Posn.new(totalX, totalY)
      end
    end
    
    # construct_cohesion_vector
    # returns posn
    # constructs the alignment vector, normalizes it, and adds the weight
    def construct_cohesion_vector
      cohesionVector = get_cohesion_vector
      if(cohesionVector.zero?)
        cohesionVector
      else
        normalizedCohesionVector = normalize_vector(cohesionVector)
        totalX = $COHESIONWEIGHT * normalizedCohesionVector.x
        totalY = $COHESIONWEIGHT * normalizedCohesionVector.y
        Posn.new(totalX, totalY)
      end
    end
        

    # add_adjustment_vectors
    # returns posn (a vector)
    # averages the adjustment vectors
    def add_adjustment_vectors
      adjustmentVectors = Array.new
      adjustmentVectors.push(construct_edge_vector) # edge adjustment vector
      adjustmentVectors.push(construct_nominal_speed_vector) # nominal speed vector
      adjustmentVectors.push(construct_alignment_vector) # alignment vector
      adjustmentVectors.push(construct_separation_vector) # separation vector
      adjustmentVectors.push(construct_cohesion_vector) # cohesion vector
      add_posns(adjustmentVectors)
    end
  end
  
  class GameWindow < Gosu::Window
    def initialize
      super $WIDTH, $HEIGHT, false
      self.caption = "Swarm"
      
      @background_image = Gosu::Image.new(self, "white.png", true)
      
      @critterList = Array.new()
      for i in 1..$NUMOFCRITTERS do
        @critterList.push(Critter.new(self))
      end
    end
    
    def update
      @critterList.each { |critter|
        critter.move(@critterList)
      }
    end
    
      def draw
        @background_image.draw(0, 0, 0)
        
          @critterList.each { |critter|
          critter.draw
        }
      end
  end

window = GameWindow.new
window.show  