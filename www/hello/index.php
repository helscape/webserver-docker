<?php
declare(strict_types=1);

$name = $_GET['name'] ?? 'World';
$name = is_string($name) ? trim($name) : 'World';
if ($name === '') {
    $name = 'World';
}

$base = rtrim(dirname($_SERVER['SCRIPT_NAME'] ?? '/hello/index.php'), '/');
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>Hello, <?= htmlspecialchars($name) ?></title>
    <style>
        body { font-family: system-ui, sans-serif; margin: 2rem; }
        code { background: #f2f2f2; padding: .15rem .35rem; border-radius: 4px; }
    </style>
</head>
<body>
    <h1>Hello, <?= htmlspecialchars($name) ?>!</h1>
    <p>This page is served by PHP <code><?= htmlspecialchars(PHP_VERSION) ?></code> through Nginx + PHP-FPM.</p>
    <p>Try <a href="<?= htmlspecialchars($base) ?>/?name=OpenCode"><code><?= htmlspecialchars($base) ?>/?name=OpenCode</code></a></p>
</body>
</html>
