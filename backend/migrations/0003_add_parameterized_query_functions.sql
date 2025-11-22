-- Migration: Add parameterized RPC functions to prevent SQL injection
-- Phase 2.2 RT Feature Completion - Security fix
-- Date: 2025-11-22

-- Function: Get routes serving a stop (replaces inline SQL in get_stop endpoint)
CREATE OR REPLACE FUNCTION get_routes_for_stop(p_stop_id TEXT)
RETURNS TABLE (
    route_id TEXT,
    route_short_name TEXT,
    route_long_name TEXT,
    route_type INT,
    route_color TEXT
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT r.route_id, r.route_short_name, r.route_long_name,
           r.route_type, r.route_color
    FROM routes r
    JOIN trips t ON r.route_id = t.route_id
    JOIN patterns p ON t.pattern_id = p.pattern_id
    JOIN pattern_stops ps ON p.pattern_id = ps.pattern_id
    WHERE ps.stop_id = p_stop_id
    ORDER BY r.route_short_name;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function: Search stops by name using trigram similarity (replaces inline SQL in search_stops)
CREATE OR REPLACE FUNCTION search_stops_by_name(p_query TEXT, p_limit INT)
RETURNS TABLE (
    stop_id TEXT,
    stop_name TEXT,
    stop_code TEXT,
    stop_lat NUMERIC,
    stop_lon NUMERIC,
    wheelchair_boarding INT,
    location_type INT,
    parent_station TEXT,
    score REAL
) AS $$
BEGIN
    RETURN QUERY
    SELECT s.stop_id, s.stop_name, s.stop_code, s.stop_lat, s.stop_lon,
           s.wheelchair_boarding, s.location_type, s.parent_station,
           similarity(s.stop_name, p_query) AS score
    FROM stops s
    WHERE s.stop_name ILIKE '%' || p_query || '%'
       OR s.stop_name % p_query
    ORDER BY score DESC, s.stop_name
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql STABLE;

-- Function: Get route types for a stop (replaces nested inline SQL in search_stops)
CREATE OR REPLACE FUNCTION get_route_types_for_stop(p_stop_id TEXT)
RETURNS TABLE (
    route_type INT
) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT r.route_type
    FROM patterns p
    JOIN routes r ON p.route_id = r.route_id
    JOIN pattern_stops ps ON p.pattern_id = ps.pattern_id
    WHERE ps.stop_id = p_stop_id;
END;
$$ LANGUAGE plpgsql STABLE;

-- Grant execute permissions (adjust role as needed)
GRANT EXECUTE ON FUNCTION get_routes_for_stop(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION search_stops_by_name(TEXT, INT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION get_route_types_for_stop(TEXT) TO anon, authenticated;
