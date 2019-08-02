-- CLIENT CONFIGURATION
config = {
    joinDuration = 30,                  -- Duration when will the race start when created. (seconds)
    freezeDuration = 30,                -- At what second is the player freezed when he joins? (seconds) - 0 = disabled
    hudEnabled = true,                  -- Enable racing HUD
    hudPosition = vec(0.015, 0.725),    -- Screen position to draw racing HUD (default top of the map)
    checkpointBlipColor = 5,            -- Color of the waypoint and blip
    delete_race = 5,                   	-- Removing the race in 20 seconds after a player has finished.
    notifyOfWinner = true               -- Notify all players of the winner (false will only notify the winner)
}