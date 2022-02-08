<?php

$dir = __DIR__;
if (isset($argv[1])) {
    $producehash = $argv[1] == 'producehash' ?? false;
}

// Finding all paths.
$files = shell_exec("sudo find $dir/../www/html -type f");
$files_arr = explode("\n", $files);
$hash_arr = [];
$bighash = '';

$countfiles = count($files_arr);
echo "'find' found $countfiles files." . PHP_EOL;
// Iterating file paths, getting content and hashing, then adding to array.
foreach ($files_arr as $path) {
    if (empty($path)) {
        continue;
    }
    $file = file_get_contents($path);
    $hash = md5($file);
    $path = strstr($path, '/www/html/');
    $hash_arr[$path] = $hash;
}
ksort($hash_arr);
foreach ($hash_arr as $hash) {
    $bighash .= $hash;
}
$bighash = md5($bighash);
$currentbighash = ['/www/html/' => $bighash];
$currentbighash = json_encode($currentbighash, JSON_UNESCAPED_SLASHES);
$currentfullhash = json_encode($hash_arr, JSON_UNESCAPED_SLASHES);
if (isset($producehash) && $producehash == true) {
    echo "Overwriting hash json files for release..." . PHP_EOL;
    file_put_contents("$dir/../verify/bighash.json", $currentbighash);
    file_put_contents("$dir/../verify/fullhash.json", $currentfullhash);
    echo "Done creating hash json." . PHP_EOL;
    exit(0);
}
file_put_contents("$dir/../verify/current-bighash.json", $currentbighash);
file_put_contents("$dir/../verify/current-fullhash.json", $currentfullhash);

$expectedhash = file_get_contents("$dir/../verify/bighash.json");
$expectedhash = json_decode($expectedhash);
$expectedhash = reset($expectedhash);

echo "Current Hash: $bighash" . PHP_EOL;
echo "Expected Hash: $expectedhash" . PHP_EOL;
if ($bighash != $expectedhash) {
    echo "HASH DOES NOT MATCH!" . PHP_EOL;
} else {
    echo "Hash looks okay." . PHP_EOL;
}