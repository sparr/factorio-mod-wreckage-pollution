--- Take the waiting out of a rocket launch.
---
--- The rocket fixture needs a space platform that the game built for itself, and getting
--- one means sitting through the whole launch: lights blinking, doors opening, the rocket
--- rising, engines starting, the climb, and then the cargo pod's flight to orbit. None of
--- that is what the fixture is testing, and all of it is spelled out in prototypes.
---
--- This mod is never published, so nothing here can reach a player.
local silo = data.raw["rocket-silo"]["rocket-silo"]
if silo then
  -- Each of these is the inverse of a duration in ticks, so 1 means one tick.
  silo.times_to_blink = 1
  silo.light_blinking_speed = 1
  silo.door_opening_speed = 1
  -- and these two are plain tick counts, defaulting to 30 and 120
  silo.rocket_rising_delay = 1
  silo.launch_wait_time = 1
end

local rocket = data.raw["rocket-silo-rocket"]["rocket-silo-rocket"]
if rocket then
  rocket.rising_speed = 1
  rocket.engine_starting_speed = 1
  -- the climb is a speed and an acceleration rather than a duration; a rocket that is
  -- already going fast when it starts leaves the screen almost at once
  rocket.flying_speed = 1
  rocket.flying_acceleration = 1
end

--- The processions are 2.0's cinematics: the pod's trip up to the platform and back is
--- one of them, and a timeline is a list of segments each with a length in ticks. Cutting
--- every segment to a single tick removes the flight without having to know which
--- procession belongs to which leg of the journey.
for _, procession in pairs(data.raw["procession"] or {}) do
  for _, timeline in pairs{ procession.timeline, procession.ground_timeline } do
    if type(timeline) == "table" then
      if timeline.duration then timeline.duration = 1 end
      for _, layer in pairs(timeline.layers or {}) do
        if type(layer) == "table" then
          for _, frames in pairs(layer) do
            if type(frames) == "table" then
              for _, frame in pairs(frames) do
                if type(frame) == "table" and frame.timestamp then frame.timestamp = 0 end
              end
            end
          end
        end
      end
    end
  end
end
