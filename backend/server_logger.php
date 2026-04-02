<?php
// backend/server_logger.php

function perfLog($msg)
{
    $logFile = __DIR__ . '/perf_log.txt';
    $time = microtime(true);
    $formattedTime = date('Y-m-d H:i:s') . '.' . sprintf('%03d', ($time - floor($time)) * 1000);
    $entry = "[$formattedTime] " . $_SERVER['REMOTE_ADDR'] . " - $msg\n";
    file_put_contents($logFile, $entry, FILE_APPEND);
}
?>