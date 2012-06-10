require 'rubygems'
require 'gosu'

$WIDTH = 700 # width of field
$HEIGHT = 700 # height of field
$NUMOFCRITTERS = 50 # number of critters to generate

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
    def initialize(x, y)
      @x = x
      @y = y
    end
    
    def getX
      return @x
    end
    
    def getY
      return @y
    end
    
    def setX(x)
      @x = x
    end
    
    def setY(y)
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
      @angle = getAngle(Posn.new(0, 0), @speed)
      @critterList
      @neighborList
    end
    
    def draw
        @image.draw_rot(@loc.getX, @loc.getY, @radius, @angle)
    end
    
    def move(critterList)
        @critterList = critterList
        @neighborList = getVisibleNeighbors
        adjustmentVector = addAdjustmentVectors
        @speed.setX(adjustmentVector.getX + @speed.getX)
        @speed.setY(adjustmentVector.getY + @speed.getY)
        @loc.setX(@loc.getX + @speed.getX)
        @loc.setY(@loc.getY + @speed.getY)
        @loc.setX(@loc.getX % $WIDTH)
        @loc.setY(@loc.getY % $HEIGHT)
        @angle = getAngle(Posn.new(0, 0), @speed)
    end
    
    # getLocation
    # returns posn
    # gets the position of the critter
    def getLocation
      return @loc
    end
    
    # getSpeed
    # returns posn
    # gets the speed of the critter
    def getSpeed
      return @speed
    end
    
    # getVisibleNeighbors
    # returns array of critters
    # gets the critter's visible neighbors
    # INCLUDES THE CRITTER'S SELF
    def getVisibleNeighbors
      neighbors = Array.new
      @critterList.each { |critter|
        neighborPosn = critter.getLocation
        if(visible?(neighborPosn))
          neighbors.push(critter)
        end  
      }
      if(neighbors.length > 1)
        puts neighbors.length
      end
      return neighbors
    end
      
    # getAngle(int, int)
    # returns int (an angle from 0-360)
    # 0,0 starts at top-left and both increase going to bottom-right
    # for determing critter angle, loc is (0, 0), for wall or neighbor angle, loc is @loc
    def getAngle(loc, other)
      # we need to compensate for y being reversed on the grid (change to a normal cartesian grid)
      locY = loc.getY * -1
      locX = loc.getX
      otherY = other.getY * -1
      otherX = other.getX
      # normally it's (speedy, speedx) but that gives us 0 degrees at the positive x axis.
      # to rotate 0 degrees to the positive y axis, switch the arguments
      radians = Math.atan2(otherX - locX, otherY - locY) 
      degrees = radians * 180 / Math::PI
      # compensate for negative values
      if(degrees < 0)
        degrees += 360 
      end 
       
      return degrees.round
    end 

    # visible?(posn)
    # returns bool
    # calculate if another point is visible? -- must be in field of view and close enough
    def visible?(point)
        # distance to other point (hypotenuse)
        distance = Math.hypot(@loc.getX - point.getX, @loc.getY - point.getY)
        # the angleOffOfForward is from @angle
        # calculate the specific angle off of @angle
        angleOffOfForward = (getAngle(@loc, point) - @angle)
        while(angleOffOfForward < -180) do angleOffOfForward += 360 end
        while(angleOffOfForward > 180) do angleOffOfForward -= 360 end
        
        if((distance <= $NEIGHBORRADIUS) && (angleOffOfForward.abs <= (0.5 * $FIELDOFVIEW)))
          #puts "wall visible"
          return true
        else
          #puts "wall not visible"
          return false
        end
    end

    # normalizeVector(posn)
    # returns posn
    # scales the vector down to a small fraction so weighing each vector is easier
    def normalizeVector(vector)
      x = vector.getX
      y = vector.getY
      magnitude = Math.hypot(x, y) # magnitude of vector
      newX = x / magnitude
      newY = y / magnitude
      return Posn.new(newX, newY)
    end
      
    # getRepulsionFactor(posn, posn)
    # returns posn
    # takes in a point and uses the critter's current location to calculate a repulsive force
    def getRepulsionFactor(loc, other)
      # watch out for dividing by zero
      xdiff = other.getX - loc.getX
      ydiff = other.getY - loc.getY
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
      
      return Posn.new(repulsiveX, repulsiveY)
    end
    
    # findAverageNeighbor
    # returns Posn
    # calculates the average position of every neighbor
    def findAverageNeighbor
      avgPosnX = avgPosnY = 0
      @neighborList.each { |neighbor|
        avgPosnX += neighbor.getLocation.getX
        avgPosnY += neighbor.getLocation.getY
      }
      
      # subtract current location from avg
      avgPosnX -= @loc.getX
      avgPosnY -= @loc.getY
      
      totalX = avgPosnX / (@neighborList.length - 1)
      totalY = avgPosnY / (@neighborList.length - 1)
      return Posn.new(totalX, totalY)
    end
    
    # addPosns(array)
    # returns posn
    # adds together an array of posns
    def addPosns(posnArray)
      x = y = 0
      if(posnArray.length > 0)
        for i in 0...posnArray.length
          x += posnArray[i].getX
          y += posnArray[i].getY
        end
        return Posn.new(x, y)
      else
        return Posn.new(0, 0)
      end
    end
    
    # avgPosns(array)
    # returns posn
    # averages together an array of posns.  If ignoreZeros is true, then posns like (0, 0)
    # will not be taken into the average.  If false, they will be.
    def avgPosns(posnArray, ignoreZeros = true, deletePosn = false, posnToDelete = false)
      x = y =  0
      zeroCount = 0
      if(posnArray.length > 0)
        for i in 0...posnArray.length
          x += posnArray[i].getX
          y += posnArray[i].getY
          if(posnArray[i].zero?) then zeroCount += 1 end
        end
        # avoid dividing by zero
        if(posnArray.length - zeroCount == 0)
          return Posn.new(0, 0)
        end
        puts "before subtraction: (#{x}, #{y})"
        if(deletePosn == true && posnToDelete != false)
          x = x - posnToDelete.getX
          y = y - posnToDelete.getY
        end
        puts "after subtraction: (#{x}, #{y})"

        if(ignoreZeros)
          x = x / (posnArray.length - zeroCount)
          y = y / (posnArray.length - zeroCount)
        else
          x = x / posnArray.length
          y = y / posnArray.length
        end
        
        return Posn.new(x.round, y.round)
      else
        return Posn.new(0, 0)
      end
    end
    
    # findVector
    # returns Posn
    # calculates the vector between two positions
    def findVector(posn1, posn2)
      diffX = posn2.getX - posn1.getX
      diffY = posn2.getY - posn1.getY
      return Posn.new(diffX, diffY)
    end
    
    # getNominalSpeedVector
    # returns posn
    # changes current speed to nominal speed
    def getNominalSpeedVector
      speedX = @speed.getX
      speedY = @speed.getY
      
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
        return Posn.new(newSpeedX, newSpeedY)
        
      elsif(speedX.abs != $NOMINALSPEED)
      
        if(speedX >= 0)
          newSpeedX = $NOMINALSPEED - speedX
        else
          newSpeedX = -$NOMINALSPEED - speedX
        end
        return Posn.new(newSpeedX, 0)
        
      elsif(speedY.abs != $NOMINALSPEED)
      
        if(speedY >= 0)
          newSpeedY = $NOMINALSPEED - speedY
        else
          newSpeedY = -$NOMINALSPEED - speedY
        end
        return Posn.new(0, newSpeedY)
        
      else 
        return Posn.new(0, 0)
      end
    end
    
    # getEdgeAvoidanceVector
    # returns posn( a vector)
    # if the critter is near an edge, this vector will direct them away from it
    def getEdgeAvoidanceVector
      edgeVectors = Array.new
      leftEdgePosn = Posn.new(0, @loc.getY)
      topEdgePosn = Posn.new(@loc.getX, 0)
      rightEdgePosn = Posn.new($WIDTH, @loc.getY)
      bottomEdgePosn = Posn.new(@loc.getX, $HEIGHT)
      
      if(visible?(topEdgePosn))
        edgeVectors.push(getRepulsionFactor(@loc, topEdgePosn))
      end
      if(visible?(rightEdgePosn))
        edgeVectors.push(getRepulsionFactor(@loc, rightEdgePosn))
      end
      if(visible?(bottomEdgePosn))
        edgeVectors.push(getRepulsionFactor(@loc, bottomEdgePosn))
      end
      if(visible?(leftEdgePosn))
        edgeVectors.push(getRepulsionFactor(@loc, leftEdgePosn))
      end
      if(edgeVectors.length > 0)
        return addPosns(edgeVectors)
      else
        return Posn.new(0, 0)
      end
    end
    
    # getAlignmentVector
    # returns Posn
    # calculates the average speed vector of all neighbors
    def getAlignmentVector
      # if there are no neighbors, no alignment vector change
      if(@neighborList.length < 2)
        return Posn.new(0, 0)
      end
        
      neighborSpeedArray = Array.new
      neighborX = neighborY = 0
      @neighborList.each { |neighbor|
        neighborX += neighbor.getSpeed.getX
        neighborY += neighbor.getSpeed.getY
      }
      neighborAvgX = (neighborX - @speed.getX) / (@neighborList.length - 1)
      neighborAvgY = (neighborY - @speed.getY) / (@neighborList.length - 1)
      totalX = neighborAvgX - @speed.getX
      totalY = neighborAvgY - @speed.getY
      return Posn.new(totalX, totalY)
    end
    
    # getSeparationVector
    # returns Posn
    # calculates the average position of neighbors and generates a repulsive force
    def getSeparationVector
    # if there are no neighbors, no separation vector change
      if(@neighborList.length < 2)
        return Posn.new(0, 0)
      end
      
      return getRepulsionFactor(@loc, findAverageNeighbor) # return total separation vector
    end
    
    # getCohesionVector
    # returns posn
    # calculates the average position of neighbors and generates an attractive force
    def getCohesionVector
    # if there are no neighbors, no cohesion vector change
      if(@neighborList.length < 2)
        return Posn.new(0, 0)
      end
      
      # return the vector that points to the avg neighbor's position'
      return findVector(@loc, findAverageNeighbor)
    end
    
    # constructEdgeVector
    # returns posn
    # calculates the edge adjustment vector, normalizes it, and adds the weight
    def constructEdgeVector
      edgeVector = getEdgeAvoidanceVector
      if(edgeVector.zero?)
        return edgeVector
      else
        normalizedEdgeVector = normalizeVector(edgeVector)
        totalX = ($EDGESTRENGTHWEIGHT * normalizedEdgeVector.getX)
        totalY = ($EDGESTRENGTHWEIGHT * normalizedEdgeVector.getY)
        return Posn.new(totalX, totalY)
      end
    end 
    
    # constructNominalSpeedVector
    # returns posn
    # constructs the nominal speed vector, normalizes it, and adds the weight
    def constructNominalSpeedVector
      speedVector = getNominalSpeedVector
      if(speedVector.zero?)
        return speedVector
      else
        normalizedSpeedVector = normalizeVector(speedVector)
        totalX = $NOMINALSPEEDWEIGHT * normalizedSpeedVector.getX
        totalY = $NOMINALSPEEDWEIGHT * normalizedSpeedVector.getY
        return Posn.new(totalX, totalY)
      end
    end  
    
    # constructAlignmentVector
    # returns posn
    # constructs the alignment vector, normalizes it, and adds the weight
    def constructAlignmentVector
      alignmentVector = getAlignmentVector
      if(alignmentVector.zero?)
        return alignmentVector
      else
        normalizedAlignmentVector = normalizeVector(alignmentVector)
        totalX = $ALIGNMENTWEIGHT * normalizedAlignmentVector.getX
        totalY = $ALIGNMENTWEIGHT * normalizedAlignmentVector.getY
        return Posn.new(totalX, totalY)
      end
    end
    
    # constructSeparationVector
    # returns posn
    # constructs the alignment vector, normalizes it, and adds the weight
    def constructSeparationVector
      separationVector = getSeparationVector
      if(separationVector.zero?)
        return separationVector
      else
        normalizedSeparationVector = normalizeVector(separationVector)
        totalX = $SEPARATIONWEIGHT * normalizedSeparationVector.getX
        totalY = $SEPARATIONWEIGHT * normalizedSeparationVector.getY
        return Posn.new(totalX, totalY)
      end
    end
    
    # constructCohesionVector
    # returns posn
    # constructs the alignment vector, normalizes it, and adds the weight
    def constructCohesionVector
      cohesionVector = getCohesionVector
      if(cohesionVector.zero?)
        return cohesionVector
      else
        normalizedCohesionVector = normalizeVector(cohesionVector)
        totalX = $COHESIONWEIGHT * normalizedCohesionVector.getX
        totalY = $COHESIONWEIGHT * normalizedCohesionVector.getY
        return Posn.new(totalX, totalY)
      end
    end
        

    # addAdjustmentVectors
    # returns posn (a vector)
    # averages the adjustment vectors
    def addAdjustmentVectors
      adjustmentVectors = Array.new
      adjustmentVectors.push(constructEdgeVector) # edge adjustment vector
      adjustmentVectors.push(constructNominalSpeedVector) # nominal speed vector
      adjustmentVectors.push(constructAlignmentVector) # alignment vector
      adjustmentVectors.push(constructSeparationVector) # separation vector
      adjustmentVectors.push(constructCohesionVector) # cohesion vector
      return addPosns(adjustmentVectors)
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