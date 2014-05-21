class Player
  GOOD_HEALTH = 14
  BAD_HEALTH = 4
  ENTITIES = [:ticking, :enemy, :captive, :stairs, :wall, :empty]
  DIRECTIONS = [:forward, :backward, :left, :right]

  def play_turn(warrior)
    @behavior_stack ||= [:campaign]
    puts "Behaviors: ==#{@behavior_stack.join(",")}=="
    @state = state(warrior)
    @goal_direction = dir_of_next_goal(warrior)
    do_behavior(warrior)
  end

  #Execute last behavior; if this results in a change in the
  #behavior stack, recurse.
  def do_behavior(warrior)
    old_stack_count = @behavior_stack.count
    send(@behavior_stack[-1], warrior)
    do_behavior(warrior) if old_stack_count !=  @behavior_stack.count
  end

  #This is the base behavior.
  def campaign(warrior)
    case(categorize(warrior.feel(@goal_direction)))
    when :enemy
      @behavior_stack << :fight_many
    when :captive
      warrior.rescue!(@goal_direction)
    when :ticking
      warrior.rescue!(@goal_direction)
    when :empty
      warrior.walk!(@goal_direction)
    when :stairs
      warrior.walk!(@goal_direction)
    else
      raise "agh"
    end
  end

  #Returns a hash of entities to their number of occurence in the 
  #spaces immediately surrounding the warrior.
  def state(warrior)
    sur = DIRECTIONS.map { |d| categorize(warrior.feel(d)) }
    ENTITIES.inject({}) do |h, e|
      h[e] = sur.count { |t| t == e }
      h
    end
  end

  #Categorize a space
  def categorize(s)
    ENTITIES.select { |e| s.send("#{e}?") }[0]
  end

  #Fight many behavior.  If there are no enemies, end the behavior.
  #If there's more than one enemy, bind in directions that aren't
  #in that of the next goal so as to kill the sludge in the way
  #of the goal first.
  def fight_many(warrior)
    if @state[:enemy] == 0 
      @behavior_stack.pop
    elsif @state[:enemy] > 1
      #bind not in directtion of goal s.t. kill that sludge first
      warrior.bind!(feel_direction_of_a(warrior, :enemy, DIRECTIONS - [@goal_direction]))
    else
     @behavior_stack << :fight_one
    end
  end

  #Fight one behavior.  If health is low, rest to recup first.  If
  #no enemies, end the behavior.  If there are enemies, attack or detonate.
  def fight_one(warrior)
    dir = feel_direction_of_a(warrior, :enemy)
    if warrior.health <= BAD_HEALTH && warrior.listen.any? { |s| s.enemy? }
      @behavior_stack << :shelter
    elsif @state[:enemy] == 0
      @behavior_stack.pop
    else
      attack_or_detonate(warrior, dir)
    end
  end

  #Detonate toward dir if there are multiple enemies there and no captives.
  #Otherwise, just attack in that direction.
  def attack_or_detonate(warrior, dir)
    if see_enemies?(warrior, dir) && !captive_close?(warrior)
      warrior.detonate!(dir)
    else
      warrior.attack!(dir)
    end
  end

  #Are there multiple enemies up ahead.
  def see_enemies?(warrior, dir)
    warrior.look(dir).count { |s| s.enemy? } > 1
  end

  #Is there a captive close by
  def captive_close?(warrior)
    c = warrior.listen.select { |s| s.captive? }[0]
    c && warrior.distance_of(c) < 2
  end

  #Prioritizes and returns direction of next goal.
  def dir_of_next_goal(warrior)
    #prioritize ticking first, then by distance
    sorted_spaces = warrior.listen.sort do |a,b| 
                      warrior.distance_of(a) <=> warrior.distance_of(b)
                    end
    goal = sorted_spaces.select { |s| s.ticking? }[0] || sorted_spaces[0]

    if goal
      dir = warrior.direction_of(goal)
      #if stairs are in the way, go around them
      if warrior.feel(dir).stairs?
        feel_direction_of_a(warrior, :empty, DIRECTIONS - [dir])
      else
        dir
      end
    else
      warrior.direction_of_stairs
    end
  end

  #Returns the direction toward the next felt space of type 'type'.
  #Can limit the directions attempted.
  def feel_direction_of_a(warrior, type, directions = DIRECTIONS)
    directions.select { |d| categorize(warrior.feel(d)) == type }[0]
  end

  #Sheltering behavior; if there's an enemy, bind him.  If not, if health
  # is good, end the behavior.  If health is bad, rest.
  def shelter(warrior)
    if @state[:enemy] == 1 
      warrior.bind!(feel_direction_of_a(warrior, :enemy))
    elsif warrior.health >= GOOD_HEALTH
      @behavior_stack.pop
    else
      warrior.rest!
    end
  end
end
