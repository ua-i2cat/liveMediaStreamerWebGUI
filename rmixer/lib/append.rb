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
#   


  # ==== Overview
  # Class that allows appending mixer events

  def append_modify_crop_from_stream(stream_id, crop_id, width, height, x, y, delay = 0)
    params = {
      :stream_id => stream_id.to_i,
      :crop_id => crop_id.to_i,
      :width => width.to_i,
      :height => height.to_i,
      :x => x.to_i,
      :y => y.to_i
    }

    return {:action => "modify_crop_from_source", :params => params, :delay => delay}
  end

  def append_modify_crop_resizing_from_stream(stream_id, crop_id, width, height, x, y, layer = 1, opacity = 1.0, delay = 0)
    params = {
      :stream_id => stream_id.to_i,
      :crop_id => crop_id.to_i,
      :width => width.to_i,
      :height => height.to_i,
      :x => x.to_i,
      :y => y.to_i,
      :layer => layer.to_i,
      :opacity => opacity
    }
    return {:action => "modify_crop_resizing_from_source", :params => params, :delay => delay}
  end

  def append_enable_crop_from_stream(stream_id, crop_id, delay = 0)
    params = {
      :stream_id => stream_id.to_i,
      :crop_id => crop_id.to_i
    }
    return {:action => "enable_crop_from_source", :params => params, :delay => delay}
  end

  def append_disable_crop_from_stream(stream_id, crop_id, delay = 0)
    params = {
      :stream_id => stream_id.to_i,
      :crop_id => crop_id.to_i
    }
    return {:action => "disable_crop_from_source", :params => params, :delay => delay}
  end

