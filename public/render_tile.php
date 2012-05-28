<?php

// Requirements: PHP >=5.2

$TILES_FILENAME = '/var/www/tiles.sqlite3';
$STATISTICS_FILENAME = '/var/www/statistics.sqlite3';

function region_ids_to_statistics_json($statistics_db, $region_ids)
{
    $q = 'SELECT region_id, statistics FROM region_statistics WHERE region_id IN (' . implode(',', $region_ids) . ')';
    $result = $statistics_db->query($q);
    if (!$result) return null;

    $ret = array();
    foreach ($result as $row) {
        $region_id = $row['region_id'];
        $z = $row['statistics'];
        $json = gzuncompress($z);
        $ret[$region_id] = $json;
    }

    return $ret;
}

function get_raw_tile_json($tiles_db, $zoom_level, $tile_row, $tile_column)
{
    $q = "SELECT tile_data FROM tiles WHERE zoom_level = $zoom_level AND tile_row = $tile_row AND tile_column = $tile_column";
    $result = $tiles_db->query($q);
    if (!$result) return null;
    $z = $result->fetchColumn();
    if (count($z) == 0) return null;

    return gzuncompress($z);
}

function get_tile_json($tiles_db, $statistics_db, $zoom_level, $tile_row, $tile_column)
{
    $raw_json = get_raw_tile_json($tiles_db, $zoom_level, $tile_row, $tile_column);
    if (!$raw_json) return null;

    if (preg_match_all('/"region_id":(\d+),/', $raw_json, $m)) {
        $region_ids = array_map('intval', $m[1]);
        $statistics_jsons = region_ids_to_statistics_json($statistics_db, $region_ids);

        $patterns = array();
        $replacements = array();

        foreach ($region_ids as $region_id) {
            array_push($patterns, "\"region_id\":$region_id,");
            if (isset($statistics_jsons[$region_id])) {
                array_push($replacements, '"statistics":' . $statistics_jsons[$region_id] . ',');
            } else {
                array_push($replacements, '');
            }
        }

        $json = str_replace($patterns, $replacements, $raw_json);
    } else {
        $json = $raw_json;
    }

    return $json;
}

function exit_with_404($message) {
    header($_SERVER["SERVER_PROTOCOL"] . ' 404 Not Found');
    exit($message);
}

if (!preg_match('|/(\d+)/(\d+)/(\d+).(?:geo)?json|', $_SERVER['REQUEST_URI'], $m)) {
    exit_with_404("URLs must end with '/zoom_level/tile_column/tile_row.json'");
}

$tiles_db = new PDO("sqlite:$TILES_FILENAME");
$statistics_db = new PDO("sqlite:$STATISTICS_FILENAME");

$zoom_level = intval($m[1]);
$tile_column = intval($m[2]);
$tile_row = intval($m[3]);

header('Content-type', 'application/json; charset=utf-8');

$tile_json = get_tile_json($tiles_db, $statistics_db, $zoom_level, $tile_row, $tile_column);
if (!$tile_json) exit_with_404('{}');

exit($tile_json);
