# Encoding: UTF-8

# The tutorial game over a landscape rendered with OpenGL.
# Basically shows how arbitrary OpenGL calls can be put into
# the block given to Window#gl, and that Gosu Images can be
# used as textures using the gl_tex_info call.

require 'rubygems'
require 'gosu'
require 'gl'

WIDTH, HEIGHT = 1200, 800
FULLSCREEN = true
TWO_PLAYER = ARGV.dig(1) || false

module ZOrder
  Background, Stars, Player, Cptn, UI = *0..4
end

# The only really new class here.
# Draws a scrolling, repeating texture with a randomized height map.
class GLBackground
  # Height map size
  POINTS_X = 7
  POINTS_Y = 7
  # Scrolling speed
  SCROLLS_PER_STEP = 50

  def initialize
    @image = Gosu::Image.new("media/earth.png", :tileable => true)
    @scrolls = 0
    @height_map = Array.new(POINTS_Y) { Array.new(POINTS_X) { rand } }
  end
  
  def scroll
    @scrolls += 1
    if @scrolls == SCROLLS_PER_STEP then
      @scrolls = 0
      @height_map.shift
      @height_map.push Array.new(POINTS_X) { rand }
    end
  end
  
  def draw(z)
    # gl will execute the given block in a clean OpenGL environment, then reset
    # everything so Gosu's rendering can take place again.
    Gosu::gl(z) { exec_gl }
  end
  
  private
  
  include Gl
  
  def exec_gl
    glClearColor(0.0, 0.2, 0.5, 1.0)
    glClearDepth(0)
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    
    # Get the name of the OpenGL texture the Image resides on, and the
    # u/v coordinates of the rect it occupies.
    # gl_tex_info can return nil if the image was too large to fit onto
    # a single OpenGL texture and was internally split up.
    info = @image.gl_tex_info
    return unless info

    # Pretty straightforward OpenGL code.
    
    glDepthFunc(GL_GEQUAL)
    glEnable(GL_DEPTH_TEST)
    glEnable(GL_BLEND)

    glMatrixMode(GL_PROJECTION)
    glLoadIdentity
    glFrustum(-0.10, 0.10, -0.075, 0.075, 1, 100)

    glMatrixMode(GL_MODELVIEW)
    glLoadIdentity
    glTranslate(0, 0, -4)
  
    glEnable(GL_TEXTURE_2D)
    glBindTexture(GL_TEXTURE_2D, info.tex_name)
    
    offs_y = 1.0 * @scrolls / SCROLLS_PER_STEP
    
    0.upto(POINTS_Y - 2) do |y|
      0.upto(POINTS_X - 2) do |x|
        glBegin(GL_TRIANGLE_STRIP)
          z = @height_map[y][x]
          glColor4d(1, 1, 1, z)
          glTexCoord2d(info.left, info.top)
          glVertex3d(-0.5 + (x - 0.0) / (POINTS_X-1), -0.5 + (y - offs_y - 0.0) / (POINTS_Y-2), z)

          z = @height_map[y+1][x]
          glColor4d(1, 1, 1, z)
          glTexCoord2d(info.left, info.bottom)
          glVertex3d(-0.5 + (x - 0.0) / (POINTS_X-1), -0.5 + (y - offs_y + 1.0) / (POINTS_Y-2), z)
        
          z = @height_map[y][x + 1]
          glColor4d(1, 1, 1, z)
          glTexCoord2d(info.right, info.top)
          glVertex3d(-0.5 + (x + 1.0) / (POINTS_X-1), -0.5 + (y - offs_y - 0.0) / (POINTS_Y-2), z)

          z = @height_map[y+1][x + 1]
          glColor4d(1, 1, 1, z)
          glTexCoord2d(info.right, info.bottom)
          glVertex3d(-0.5 + (x + 1.0) / (POINTS_X-1), -0.5 + (y - offs_y + 1.0) / (POINTS_Y-2), z)
        glEnd
      end
    end
  end
end

# Roughly adapted from the tutorial game. Always faces north.
class Player
  
  
  attr_reader :score, :x, :y, :speed

  def initialize(x, y)
    @image = Gosu::Image.new("media/starfighter.bmp")
    @big_image = Gosu::Image.new("media/big_starfighter.bmp")
    @current_image = @image
    @beep = Gosu::Sample.new("media/boop.wav")
    @jet = Gosu::Sample.new("media/jetsons.wav")
    @x, @y = x, y
    @score = 0
    @speed = 7
  end

  def move_left
    @x = [@x - speed, 0].max
  end
  
  def move_right
    @x = [@x + speed, WIDTH].min
  end
  
  def accelerate
    @y = [@y - speed, 50].max
  end
  
  def brake
    @y = [@y + speed, HEIGHT].min
  end

  def hyper_mode
    @jet.play
    @current_image = @big_image
    @speed = 7
  end

  def normal_mode
    @current_image = @image
    @speed = 7
  end
  
  def draw
    @current_image.draw(@x - @current_image.width / 2, @y - @current_image.height / 2, ZOrder::Player)
  end

  def collect_stars(stars)
    stars.reject! do |star|
      if Gosu::distance(@x, @y, star.x, star.y) < (0.7*@current_image.width) then
        @score += 10
        @beep.play
        true
      else
        false
      end
    end
  end
end

# Also taken from the tutorial, but drawn with draw_rot and an increasing angle
# for extra rotation coolness!
class Star
  attr_reader :x, :y
  
  def initialize(animation)
    @animation = animation
    @color = Gosu::Color.new(0xff_000000)
    @color.red = rand(255 - 40) + 40
    @color.green = rand(255 - 40) + 40
    @color.blue = rand(255 - 40) + 40
    @x = rand * 800
    @y = 0
  end

  def draw  
    img = @animation[Gosu::milliseconds / 100 % @animation.size];
    img.draw_rot(@x, @y, ZOrder::Stars, @y, 0.5, 0.5, 1, 1, @color, :add)
  end
  
  def update
    # Move towards bottom of screen
    @y += 5
    # Return false when out of screen (gets deleted then)
    @y < 650
  end
end

# Cap Class
class CptnPlayer
  attr_reader :x, :y, :score, :close_star
  attr_reader :speed

  def initialize(map, x, y)
    @x, @y = x, y
    @dir = :left
    @score = 0
    @speed = 3
    @close_star
    # @vy = 0 # Vertical velocity
    @map = map
    # Load all animation frames
    @standing, @walk1, @walk2, @jump = *Gosu::Image.load_tiles("media/cptn_z.png", 50, 50)
    @a_standing, @a_walk1, @a_walk2, @a_jump = *Gosu::Image.load_tiles("media/cptn_z_angry.png", 50, 50)
    # This always points to the frame that is currently drawn.
    # This is set in update, and used in draw.
    @cur_image = @jump
    @kpow = Gosu::Sample.new("media/kpow.wav")
  end
  
  def draw
    # Flip vertically when facing to the left.
    if @dir == :left then
      offs_x = -25
      factor = 1.0
    else
      offs_x = 25
      factor = -1.0
    end
    @cur_image.draw(@x + offs_x, @y - 49, ZOrder::Cptn, factor, 1.0)
  end
  
  def go_fast
    @speed = 12
    @cur_image = @a_jump
  end

  def go_normal
    @speed = 3
    @cur_image = @jump
  end

  def move_left
    @x = [@x - speed, 0].max
  end
  
  def move_right
    @x = [@x + speed, WIDTH].min
  end
  
  def move_up
    @y = [@y - speed, 50].max
  end
  
  def move_down
    @y = [@y + speed, HEIGHT].min
  end
  
  def closest_star(stars)
    stars.select do |star|
      star.y < 400 && star.x < 600
    end.min_by do |star| 
      Gosu::distance(@x, @y, star.x, star.y)
    end
  end

  def move_toward_closest_star(stars)
    star = closest_star(stars)
    @close_star = star
    return unless star

    y_diff = star.y - @y
    x_diff = star.x - @x
    if y_diff.abs > x_diff.abs
      if y_diff > 0
        move_down
      else
        move_up
      end
    else
      if x_diff > 0
        move_right
      else
        move_left
      end
    end
  end

  def collect_stars(stars)
    stars.reject! do |star|
      if Gosu::distance(@x, @y, star.x, star.y) < 35 then
        @score += 10
        @kpow.play
        true
      else
        false
      end
    end
  end
end

class OpenGLIntegration < (Example rescue Gosu::Window)
  ONE_PLAYER = 1
  TWO_PLAYER = 2

  def initialize
    super WIDTH, HEIGHT, FULLSCREEN
    
    self.caption = "Captain Zipcar VS The World"
      
    @soundtrack = Gosu::Song.new("media/earth.wav")
    @soundtrack.play(looping = true)
    
    @gl_background = GLBackground.new
    
    @player = Player.new(400, 500)
    @cptn = CptnPlayer.new(nil, 400, 500)

    @player_mode = ONE_PLAYER
    
    @star_anim = Gosu::Image::load_tiles("media/star.png", 25, 25)
    @stars = Array.new
    
    @font = Gosu::Font.new(20)
  end
  
  def update
    @player.collect_stars(@stars)
    @cptn.collect_stars(@stars)

    if @player_mode == TWO_PLAYER
      if [Gosu::KbLeft, Gosu::GpButton4, Gosu::GpButton13].find(&Gosu.method(:button_down?))
        @player.move_left
      end
      
      if [Gosu::KbRight, Gosu::GpButton5, Gosu::GpButton14].find(&Gosu.method(:button_down?))
        @player.move_right
      end

      if Gosu::button_down? Gosu::GpButton11 or Gosu::button_down? Gosu::KbUp
        @player.accelerate
      end
      if Gosu::button_down? Gosu::GpButton12 or Gosu::button_down? Gosu::KbDown
        @player.brake
      end
      if Gosu::button_down? Gosu::GpButton0 or Gosu::button_down? Gosu::KbSpace
        @player.hyper_mode
      else
        @player.normal_mode
      end

      if Gosu::button_down? Gosu::KbA
        @cptn.move_left
      end
      if Gosu::button_down? Gosu::KbD
        @cptn.move_right
      end
      if Gosu::button_down? Gosu::KbW
        @cptn.move_up
      end
      if Gosu::button_down? Gosu::KbS
        @cptn.move_down
      end
      if Gosu::button_down? Gosu::KbLeftShift
        @cptn.go_fast
      else
        @cptn.go_normal
      end
    else
      if [Gosu::GpButton13, Gosu::KbLeft].find(&Gosu.method(:button_down?))
        @player.move_left
      end
      
      if [Gosu::GpButton14, Gosu::KbRight].find(&Gosu.method(:button_down?))
        @player.move_right
      end

      if [Gosu::GpButton11, Gosu::KbUp].find(&Gosu.method(:button_down?))
        @player.accelerate 
      end

      if [Gosu::GpButton12, Gosu::KbDown].find(&Gosu.method(:button_down?))
        @player.brake 
      end
      
      if [Gosu::GpButton0, Gosu::KbSpace].find(&Gosu.method(:button_down?))
      # if Gosu::button_down? Gosu::GpButton0
        @player.hyper_mode
      else
        @player.normal_mode
      end

      if @player.score > @cptn.score
        @cptn.go_fast
      else
        @cptn.go_normal
      end
      @cptn.move_toward_closest_star(@stars)
    end

    if Gosu::button_down? Gosu::Kb1
      @player_mode = ONE_PLAYER
    end

    if Gosu::button_down? Gosu::Kb2
      @player_mode = TWO_PLAYER
    end
    
    @stars.reject! { |star| !star.update }
    
    @gl_background.scroll
    
    @stars.push(Star.new(@star_anim)) if rand(10) == 0
  end

  def draw
    @player.draw
    @cptn.draw
    @stars.each { |star| star.draw }
    if @player_mode == ONE_PLAYER
      @font.draw("One player mode (press '2' to switch)", 10, 10, ZOrder::UI, 1.0, 1.0, 0xff_ffff00)
    else
      @font.draw("Two player mode (press '1' to switch)", 10, 10, ZOrder::UI, 1.0, 1.0, 0xff_ffff00)
      @font.draw("PLAYER TWO: WASD + LSHIFT", 900, 750, ZOrder::UI, 1.0, 1.0, 0xff_ffff00)
    end
    @font.draw("Score: #{@player.score}", 10, 40, ZOrder::UI, 1.0, 1.0, 0xff_ffff00)
    @font.draw("CPT ZIPCAR Score: #{@cptn.score}", 10, 80, ZOrder::UI, 1.0, 1.0, 0xff_ffff00)

    @font.draw("PLAYER ONE: KEYS + SPACE, GPAD + A-BUTTON ", 10, 750, ZOrder::UI, 1.0, 1.0, 0xff_ffff00)
    @gl_background.draw(ZOrder::Background)
  end
end

OpenGLIntegration.new.show if __FILE__ == $0