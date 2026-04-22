-- Run Gaps totals and Avg by Players

SELECT 
	rusher_player_name,
	rusher_player_id,
    run_gap,
    COUNT(*) AS attempts,
    SUM(rushing_yards) AS total_yards,
    AVG(rushing_yards) AS avg_yards
FROM pbp
WHERE play_type = 'run'
--AND rusher_player_name = 'D.Henry'
AND game_date BETWEEN '2025-09-07' AND '2026-01-04'
GROUP BY run_gap, rusher_player_name, rusher_player_id
ORDER BY avg_yards DESC;
