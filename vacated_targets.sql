-- Vacated team targets going into the 2026 NFL season
WITH prior_year_targets AS (
    SELECT
        CASE
            WHEN ps.team = 'LA' THEN 'LAR'
            WHEN ps.team = 'JAC' THEN 'JAX'
            ELSE ps.team
        END AS team,
        ps.player_id,
        ps.player_name,
        ps.position,
        SUM(ps.targets) AS targets_2025
    FROM player_stats ps
    WHERE ps.season = 2025
      AND ps.season_type = 'REG'
    GROUP BY
        CASE
            WHEN ps.team = 'LA' THEN 'LAR'
            WHEN ps.team = 'JAC' THEN 'JAX'
            ELSE ps.team
        END,
        ps.player_id,
        ps.player_name,
        ps.position
),

latest_depth_chart AS (
    SELECT
        dc.gsis_id,
        CASE
            WHEN dc.team = 'LA' THEN 'LAR'
            WHEN dc.team = 'JAC' THEN 'JAX'
            ELSE dc.team
        END AS team,
        dc.dt,
        ROW_NUMBER() OVER (
            PARTITION BY dc.gsis_id
            ORDER BY dc.dt DESC
        ) AS rn
    FROM depth_charts dc
    WHERE dc.season = 2026
      AND dc.gsis_id IS NOT NULL
      AND dc.team IS NOT NULL
      AND dc.team NOT LIKE '%/%'
      AND dc.team NOT IN (
          'Cardinals','Falcons','Ravens','Bills','Panthers','Bears','Bengals','Browns',
          'Cowboys','Broncos','Lions','Packers','Texans','Colts','Jaguars','Chiefs',
          'Raiders','Chargers','Rams','Dolphins','Vikings','Patriots','Saints','Giants',
          'Jets','Eagles','Steelers','Seahawks','49ers','Buccaneers','Titans','Commanders'
      )
),

current_roster AS (
    SELECT
        ldc.gsis_id,
        ldc.team
    FROM latest_depth_chart ldc
    WHERE ldc.rn = 1
      AND EXISTS (
          SELECT 1
          FROM contracts c
          WHERE c.gsis_id = ldc.gsis_id
            AND c.is_active = 1
      )
),

team_targets_2025 AS (
    SELECT
        pyt.team,
        SUM(pyt.targets_2025) AS total_targets_2025
    FROM prior_year_targets pyt
    GROUP BY pyt.team
),

returning_targets AS (
    SELECT
        pyt.team,
        SUM(pyt.targets_2025) AS returning_targets_2025
    FROM prior_year_targets pyt
    JOIN current_roster cr
        ON pyt.player_id = cr.gsis_id
       AND pyt.team = cr.team
    GROUP BY pyt.team
),

vacated_by_position AS (
    SELECT
        pyt.team,
        SUM(CASE WHEN pyt.position IN ('RB','HB','FB') THEN pyt.targets_2025 ELSE 0 END) AS vacated_rb_targets,
        SUM(CASE WHEN pyt.position = 'WR' THEN pyt.targets_2025 ELSE 0 END) AS vacated_wr_targets,
        SUM(CASE WHEN pyt.position = 'TE' THEN pyt.targets_2025 ELSE 0 END) AS vacated_te_targets
    FROM prior_year_targets pyt
    LEFT JOIN current_roster cr
        ON pyt.player_id = cr.gsis_id
       AND pyt.team = cr.team
    WHERE cr.gsis_id IS NULL
    GROUP BY pyt.team
)

SELECT
    t.team,
    t.total_targets_2025,
    ISNULL(r.returning_targets_2025, 0) AS targets_still_on_2026_roster,
    t.total_targets_2025 - ISNULL(r.returning_targets_2025, 0) AS vacated_targets,
    ISNULL(v.vacated_rb_targets, 0) AS vacated_rb_targets,
    ISNULL(v.vacated_wr_targets, 0) AS vacated_wr_targets,
    ISNULL(v.vacated_te_targets, 0) AS vacated_te_targets
FROM team_targets_2025 t
LEFT JOIN returning_targets r
    ON t.team = r.team
LEFT JOIN vacated_by_position v
    ON t.team = v.team