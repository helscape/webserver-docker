<?php
declare(strict_types=1);

function env(string $key, string $default = ''): string
{
    $v = getenv($key);
    return $v === false ? $default : $v;
}

$results = [];

try {
    $pdo = new PDO(
        sprintf(
            'mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
            env('MARIADB_HOST', 'mariadb'),
            env('MARIADB_PORT', '3306'),
            env('MARIADB_DATABASE', env('DB_NAME', 'appdb'))
        ),
        env('MARIADB_USER', env('DB_USER', 'appuser')),
        env('MARIADB_PASSWORD', env('DB_PASSWORD', '')),
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_TIMEOUT => 2]
    );
    $results['mariadb'] = (string) $pdo->query('SELECT VERSION()')->fetchColumn();
} catch (Throwable $e) {
    $results['mariadb'] = 'n/a: ' . $e->getMessage();
}

try {
    $pdo = new PDO(
        sprintf(
            'pgsql:host=%s;port=%s;dbname=%s;connect_timeout=2',
            env('POSTGRES_HOST', 'postgres'),
            env('POSTGRES_PORT', '5432'),
            env('POSTGRES_DB', env('DB_NAME', 'appdb'))
        ),
        env('POSTGRES_USER', env('DB_USER', 'appuser')),
        env('POSTGRES_PASSWORD', env('DB_PASSWORD', '')),
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]
    );
    $results['postgres'] = (string) $pdo->query('SELECT version()')->fetchColumn();
} catch (Throwable $e) {
    $results['postgres'] = 'n/a: ' . $e->getMessage();
}
?>
<!doctype html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>Webserver Stack OK</title>
    <style>
        body { font-family: system-ui, sans-serif; margin: 2rem; }
        code { background: #f2f2f2; padding: .15rem .35rem; border-radius: 4px; }
        table { border-collapse: collapse; margin-top: 1rem; }
        th, td { border: 1px solid #ccc; padding: .4rem .7rem; text-align: left; }
    </style>
</head>
<body>
    <h1>PHP + Nginx + Database: OK</h1>
    <p>PHP version: <code><?= htmlspecialchars(PHP_VERSION) ?></code></p>
    <table>
        <tr><th>Service</th><th>Version / Status</th></tr>
        <?php foreach ($results as $svc => $val): ?>
            <tr>
                <td><?= htmlspecialchars($svc) ?></td>
                <td><?= htmlspecialchars((string) $val) ?></td>
            </tr>
        <?php endforeach; ?>
    </table>
</body>
</html>
