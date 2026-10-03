<?php
// Crystal updater: install this file at /var/www/crystalgames/api/updater.php.
// Common assets live in api/files/{init.lua,data,modules,mods}.
$files_dir = __DIR__ . DIRECTORY_SEPARATOR . 'files';
$files_url = 'https://crystalgames.com.br/api/files'; // No trailing slash.
$common_roots = array('init.lua', 'data', 'modules', 'mods');
$cache_interval = 60;

// Prefer separate package directories; legacy root filenames remain supported.
// Do not use the Linux executable as a macOS executable.
$desktop_binaries = array(
    'windows' => array('binaries/windows/x64/Clientex64.exe', 'binaries/windows/x64/Crystal.exe', 'binaries/windows/Crystal.exe', 'Crystal.exe', 'otclient_x64.exe'),
    'linux' => array('binaries/linux/Crystal', 'Crystal'),
    'mac' => array('binaries/mac/Crystal', 'Crystal-mac')
);
$mobile_packages = array(
    'android' => array(
        array('metadata' => 'binaries/android/android-version.json', 'file' => 'binaries/android/Crystal.apk'),
        array('metadata' => 'android-version.json', 'file' => 'Crystal.apk')
    ),
    'ios' => array(
        array('metadata' => 'binaries/ios/ios-version.json', 'file' => 'binaries/ios/Crystal.ipa'),
        array('metadata' => 'ios-version.json', 'file' => 'Crystal.ipa')
    )
);

function respond($body, $status = 200) {
    http_response_code($status);
    header('Content-Type: application/json; charset=utf-8');
    header('Access-Control-Allow-Origin: *');
    header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
    $json = json_encode($body, JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT);
    if ($json === false) {
        http_response_code(500);
        $json = '{"error":"Unable to encode updater response"}';
    }
    echo $json;
    exit;
}

function fail($message, $status = 400) {
    respond(array('error' => $message), $status);
}

function crcForClient($file) {
    $crc = hash_file('crc32b', $file);
    if ($crc === false) {
        fail('Unable to calculate updater checksum', 500);
    }
    $crc = ltrim(strtolower($crc), '0');
    return $crc === '' ? '0' : $crc;
}

function packagePath($root, $relative) {
    $real = realpath($root . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $relative));
    $prefix = $root . DIRECTORY_SEPARATOR;
    if ($real === false || !is_file($real) || strncmp($real, $prefix, strlen($prefix)) !== 0) {
        return null;
    }
    return $real;
}

function clientFamily($os, $platform) {
    $platforms = array(
        'windows' => array('WIN32-WGL', 'WIN32-EGL', 'WIN32-WGL-GCC', 'WIN32-EGL-GCC'),
        'linux' => array('X11-GLX', 'X11-EGL'),
        'mac' => array('COCOA-MACOS'),
        'android' => array('ANDROID-EGL', 'ANDROID64-EGL'),
        // Reserved for an iOS client that supplies these identifiers.
        'ios' => array('IOS-EGL', 'IOS-METAL', 'COCOA-IOS')
    );
    foreach ($platforms as $family => $supported) {
        if (!in_array($platform, $supported, true)) {
            continue;
        }
        // Current Android builds may report linux because of the C++ macro order.
        if ($family === 'android' && ($os === 'android' || $os === 'linux')) {
            return $family;
        }
        return $os === $family ? $family : null;
    }
    // Unknown or contradictory identifiers never receive a native package.
    return null;
}

$data = json_decode(file_get_contents('php://input'));
if (!is_object($data)) {
    fail('Invalid input data');
}
if ((isset($data->os) && !is_string($data->os)) ||
    (isset($data->platform) && !is_string($data->platform))) {
    fail('Invalid operating system or platform');
}
$os = strtolower($data->os ?? 'unknown');
$os_aliases = array('win32' => 'windows', 'win64' => 'windows', 'macos' => 'mac', 'osx' => 'mac');
$os = $os_aliases[$os] ?? $os;
$platform = strtoupper($data->platform ?? '');
$family = clientFamily($os, $platform);
if ($family === 'windows') {
    // Older Windows clients do not report their architecture and are x64.
    if (isset($data->arch) && !is_string($data->arch)) {
        fail('Invalid client architecture');
    }
    $arch = strtolower($data->arch ?? 'x64');
    if ($arch === 'x86') {
        // Never fall back to the legacy x64 executable for a 32-bit client.
        $desktop_binaries['windows'] = array('binaries/windows/x86/Clientex86.exe');
    } elseif ($arch !== 'x64') {
        $desktop_binaries['windows'] = array();
    }
}
$args = isset($data->args) && is_object($data->args) ? $data->args : new stdClass();
$root = realpath($files_dir);
if ($root === false || !is_dir($root)) {
    fail('Updater files directory not found', 500);
}
$files_url = rtrim($files_url, '/');

// Cache only common assets. Package hashes are calculated from the selected file.
// Scope by installation and source version to avoid old/shared checksums.txt data.
$cache_file = sys_get_temp_dir() . DIRECTORY_SEPARATOR . 'crystal-updater-v3-' .
    hash('sha256', $root . __FILE__ . hash_file('sha256', __FILE__)) . '.json';
$files = null;
if (is_file($cache_file) && filemtime($cache_file) + $cache_interval > time()) {
    $cached = json_decode(file_get_contents($cache_file), true);
    if (is_array($cached) && ($cached['schema'] ?? null) === 3 && isset($cached['files']) && is_array($cached['files'])) {
        $files = $cached['files'];
    }
}
if ($files === null) {
    $files = array();
    try {
        foreach ($common_roots as $common_root) {
            $start = $root . DIRECTORY_SEPARATOR . $common_root;
            if (is_file($start)) {
                $entries = array(new SplFileInfo($start));
            } elseif (is_dir($start)) {
                $entries = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($start, FilesystemIterator::SKIP_DOTS));
            } else {
                continue;
            }
            foreach ($entries as $entry) {
                if (!$entry->isFile()) {
                    continue;
                }
                $absolute = $entry->getPathname();
                $relative = str_replace(DIRECTORY_SEPARATOR, '/', substr($absolute, strlen($root) + 1));
                // Native executables, libraries and installers cannot become shared assets.
                if (preg_match('/\.(?:exe|dll|apk|ipa|dylib|dmg|pkg|deb|rpm|so(?:\.[0-9]+)*)$/i', $relative) ||
                    preg_match('/\.app(?:\/|$)/i', $relative)) {
                    continue;
                }
                if (packagePath($root, $relative) === null) {
                    continue;
                }
                $files['/' . ltrim($relative, '/')] = crcForClient($absolute);
            }
        }
    } catch (Throwable $error) {
        fail('Unable to read updater assets', 500);
    }
    ksort($files);
    // A unique staging name prevents concurrent requests overwriting the same .tmp.
    $temporary = tempnam(sys_get_temp_dir(), 'crystal-updater-');
    if ($temporary !== false) {
        $cache_json = json_encode(array('schema' => 3, 'files' => $files));
        if ($cache_json !== false && file_put_contents($temporary, $cache_json, LOCK_EX) !== false) {
            if (!@rename($temporary, $cache_file)) {
                @unlink($temporary);
            }
        } else {
            @unlink($temporary);
        }
    }
    // Cache failures do not prevent serving the freshly computed manifest.
}
$ret = array('url' => $files_url, 'files' => (object)$files, 'keepFiles' => false);

if ($family !== null && isset($desktop_binaries[$family])) {
    foreach ($desktop_binaries[$family] as $relative) {
        $absolute = packagePath($root, $relative);
        if ($absolute !== null) {
            $ret['binary'] = array('file' => '/' . $relative, 'checksum' => crcForClient($absolute));
            break;
        }
    }
}

if ($family !== null && isset($mobile_packages[$family])) {
    foreach ($mobile_packages[$family] as $candidate) {
        $metadata_path = packagePath($root, $candidate['metadata']);
        $package_path = packagePath($root, $candidate['file']);
        if ($metadata_path === null || $package_path === null) {
            continue;
        }
        $metadata = json_decode(file_get_contents($metadata_path), true);
        if (!is_array($metadata)) {
            fail('Invalid mobile package metadata', 500);
        }
        $version = filter_var($metadata['versionCode'] ?? null, FILTER_VALIDATE_INT, array('options' => array('min_range' => 1)));
        if ($version === false) {
            fail('Invalid mobile package versionCode', 500);
        }
        $version_arg = $family === 'android' ? 'androidVersionCode' : 'iosVersionCode';
        $current = filter_var($args->$version_arg ?? 0, FILTER_VALIDATE_INT, array('options' => array('min_range' => 0)));
        if ($current === false) {
            fail('Invalid client package versionCode');
        }
        if ($version > $current) {
            $sha256 = hash_file('sha256', $package_path);
            if ($sha256 === false) {
                fail('Unable to calculate mobile package checksum', 500);
            }
            $field = $family === 'android' ? 'androidPackage' : 'iosPackage';
            $encoded_path = implode('/', array_map('rawurlencode', explode('/', $candidate['file'])));
            $ret[$field] = array(
                'versionCode' => $version,
                'versionName' => strval($metadata['versionName'] ?? $version),
                'url' => $files_url . '/' . $encoded_path,
                'sha256' => $sha256
            );
        }
        break;
    }
}
respond($ret);
