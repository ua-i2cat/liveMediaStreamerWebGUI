#
#  RUBYMIXER - A management ruby interface for MIXER
#  Copyright (C) 2013  Fundació i2CAT, Internet i Innovació digital a Catalunya
#
#  This file is part of thin RUBYMIXER.
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#  Authors:  Marc Palau <marc.palau@i2cat.net>,
#            Ignacio Contreras <ignacio.contreras@i2cat.net>
#

def calcRegularGrid(cellsX = 2, cellsY = 2)
  grid = {:id => "#{cellsX}x#{cellsY}"}
  positions = []
  idCounter = 1
  width = 1.0/cellsX
  height = 1.0/cellsY
  cellsY.times do |i|
    cellsX.times do |j|
      positions << {
        :id => idCounter,
        :channel => 0,
        :width => width,
        :height => height,
        :x => j * (1.0/cellsX),
        :y => i * (1.0/cellsY),
        :opacity => 1.0,
        :layer => 0
      }
      idCounter += 1
    end
  end

  grid[:positions] = positions

  return grid
end

def calcPictureInPicture (box_width = 0.25, box_height = 0.25)
  grid = {:id => "PiP"}
  positions = []
  width = 1.0
  height = 1.0
  positions << {
    :id => 1,
    :channel => 0,
    :width => width,
    :height => height,
    :x => 0,
    :y => 0,
    :opacity => 1.0,
    :layer => 0
  }

  positions << {
    :id => 2,
    :channel => 0,
    :width => box_width,
    :height => box_height,
    :x => width - box_width,
    :y => height - box_height,
    :opacity => 1.0,
    :layer => 1
  }

  grid[:positions] = positions

  return grid

end

def calcPreviewGrid
  grid = calcRegularGrid(3,3)
  grid[:id] = "preview"

  grid[:positions].each do |p|
    p[:channel] = p[:id]
  end

  return grid
end

def calcSideBySide
  grid = {:id => "SbS"}
  positions = []
  width = 0.5
  height = 0.5
  y = 0.5 - height/2

  positions << {
    :id => 1,
    :channel => 0,
    :width => 0.5,
    :height => height,
    :x => 0,
    :y => y,
    :layer => 0,
    :opacity => 1.0
  }

  positions << {
    :id => 2,
    :channel => 0,
    :width => 0.5,
    :height => height,
    :x => 0.5,
    :y => y,
    :layer => 0,
    :opacity => 1.0
  }

  grid[:positions] = positions

  return grid
end

def calc_regular_grid (cells_x = 2, cells_y = 2)

  grid = []
  width = 1.0/cells_x
  height = 1.0/cells_y
  cells_y.times do |i|
    cells_x.times do |j|
      grid << {
        :width => width,
        :height => height,
        :x => j * (1.0/cells_x),
        :y => i * (1.0/cells_y),
        :layer => 0,
        :opacity => 1.0
      }
    end
  end

return grid

end

def calc_upper_left_grid_6 (up_left_width = 0.75, up_left_height = 0.75)

  grid = []
  up_right_width = 1.0 - up_left_width
  up_right_height = up_left_height / 2
  down_left_width = up_left_width / 2
  down_left_height = 1.0 - up_left_height
  down_right_width = up_right_width
  down_right_height = down_left_height
  grid << {
    :width => up_left_width,
    :height => up_left_height,
    :x => 0,
    :y => 0,
    :layer => 0,
    :opacity => 1.0
  }

  2.times do |i|
    grid << {
      :width => up_right_width,
      :height => up_right_height,
      :x => up_left_width,
      :y => i * up_right_height,
      :layer => 0,
      :opacity => 1.0
    }
  end

  2.times do |i|
    grid << {
      :width => down_left_width,
      :height => down_left_height,
      :x => i * down_left_width,
      :y => up_left_height,
      :layer => 0,
      :opacity => 1.0
    }
  end

  grid << {
    :width => down_right_width,
    :height => down_right_height,
    :x => up_left_width,
    :y => up_left_height,
    :layer => 0,
    :opacity => 1.0
  }

  return grid

end

def calc_down_right_box (box_width = 0.25, box_height = 0.25)
  grid = []
  width = 1.0
  height = 1.0
  grid << {
    :width => width,
    :height => height,
    :x => 0,
    :y => 0,
    :layer => 0,
    :opacity => 1.0
  }

  grid << {
    :width => box_width,
    :height => box_height,
    :x => width - box_width,
    :y => height - box_height,
    :layer => 1,
    :opacity => 1.0
  }

  return grid

end

def calc_side_by_side
  grid = []
  width = 0.5
  height = 0.5
  y = 0.5 - height/2

  grid << {
    :width => 0.5,
    :height => height,
    :x => 0,
    :y => y,
    :layer => 10,
    :opacity => 1.0
  }

  grid << {
    :width => 0.5,
    :height => height,
    :x => 0.5,
    :y => y,
    :layer => 10,
    :opacity => 1.0
  }

  return grid
end

def calc_idt_grid(id)
grid = []
width = 1.0
height = 1.0

grid = case id
  when 7
    calc_idt_1 #side_by_side_plus_background
  when 8
    calc_idt_2 #side_by_side_plus_background_swaped
  when 9
    calc_idt_3 #background_plus_down_corners
  when 10
    calc_idt_4 #background_plus_down_corners_swaped
  when 11
    calc_idt_5 #three-side-by-side
  when 12
    calc_idt_6 #three-side-by-side-swaped
  when 13
    calc_idt_7 #two-active-blending
  when 14
    calc_idt_8 #two-active-blending-swaped
  end

  return grid
end

def calc_idt_1 #side_by_side_plus_background
  grid = []
  width = 0.5
  height = 0.5
  y = 0.5 - height/2

  grid << {
    :width => width,
    :height => height,
    :x => 0,
    :y => y,
    :layer => 10,
    :opacity => 1.0
  }

  grid << {
    :width => width,
    :height => height,
    :x => 0.5,
    :y => y,
    :layer => 10,
    :opacity => 1.0
  }

  grid << {
    :width => 1.0,
    :height => 1.0,
    :x => 0,
    :y => 0,
    :layer => 0,
    :opacity => 1.0
  }

  return grid

end

def calc_idt_2 #side_by_side_plus_background_swaped
  grid = []
  width = 0.5
  height = 0.5
  y = 0.5 - height/2

  grid << {
    :width => width,
    :height => height,
    :x => 0.5,
    :y => y,
    :layer => 10,
    :opacity => 1.0
  }

  grid << {
    :width => width,
    :height => height,
    :x => 0,
    :y => y,
    :layer => 10,
    :opacity => 1.0
  }

  grid << {
    :width => 1.0,
    :height => 1.0,
    :x => 0,
    :y => 0,
    :layer => 0,
    :opacity => 1.0
  }

  return grid

end

def calc_idt_3 #background_plus_down_corners
  grid = []
  width = 0.4
  height = 0.4

  grid << {
    :width => width,
    :height => height,
    :x => 0,
    :y => 0.6,
    :layer => 10,
    :opacity => 1.0
  }

  grid << {
    :width => width,
    :height => height,
    :x => 0.6,
    :y => 0.6,
    :layer => 10,
    :opacity => 1.0
  }

  grid << {
    :width => 1.0,
    :height => 1.0,
    :x => 0,
    :y => 0,
    :layer => 0,
    :opacity => 1.0
  }

  return grid

end

def calc_idt_4 #background_plus_down_corners_swaped
  grid = []
  width = 0.4
  height = 0.4

  grid << {
    :width => width,
    :height => height,
    :x => 0.6,
    :y => 0.6,
    :layer => 10,
    :opacity => 1.0
  }

  grid << {
    :width => width,
    :height => height,
    :x => 0,
    :y => 0.6,
    :layer => 10,
    :opacity => 1.0
  }

  grid << {
    :width => 1.0,
    :height => 1.0,
    :x => 0,
    :y => 0,
    :layer => 0,
    :opacity => 1.0
  }

  return grid
end

def calc_idt_5 #three-side-by-side
  grid = []
  width = 0.33
  height = 0.33
  y = 0.5 - height/2

  grid << {
    :width => width,
    :height => height,
    :x => 0,
    :y => y,
    :layer => 0,
    :opacity => 1.0
  }

  grid << {
    :width => width,
    :height => height,
    :x => 0.66,
    :y => y,
    :layer => 0,
    :opacity => 1.0
  }

  grid << {
    :width => width,
    :height => height,
    :x => 0.33,
    :y => y,
    :layer => 0,
    :opacity => 1.0
  }

  return grid
end

def calc_idt_6 #three-side-by-side-swaped
  grid = []
  width = 0.33
  height = 0.33
  y = 0.5 - height/2

  grid << {
    :width => width,
    :height => height,
    :x => 0.66,
    :y => y,
    :layer => 0,
    :opacity => 1.0
  }

  grid << {
    :width => width,
    :height => height,
    :x => 0,
    :y => y,
    :layer => 0,
    :opacity => 1.0
  }

  grid << {
    :width => width,
    :height => height,
    :x => 0.33,
    :y => y,
    :layer => 0,
    :opacity => 1.0
  }

  return grid
end

def calc_idt_7 #two-active-blending
  grid = []

  grid << {
    :width => 1.0,
    :height => 1.0,
    :x => 0,
    :y => 0,
    :layer => 10,
    :opacity => 0.5
  }

  grid << {
    :width => 1.0,
    :height => 1.0,
    :x => 0,
    :y => 0,
    :layer => 0,
    :opacity => 1.0
  }

  return grid
end

def calc_idt_8 #two-active-blending-swapped
  grid = []

  grid << {
    :width => 1.0,
    :height => 1.0,
    :x => 0,
    :y => 0,
    :layer => 0,
    :opacity => 1.0
  }

  grid << {
    :width => 1.0,
    :height => 1.0,
    :x => 0,
    :y => 0,
    :layer => 10,
    :opacity => 0.5
  }

  return grid
end
