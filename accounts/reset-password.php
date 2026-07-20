<?php
$resetDir = '/var/lib/mail-password-resets';

// Helper function for pretty errors (fatal -- for invalid/expired links only)
function stop($message) {
    echo "<!DOCTYPE html><html lang='en'><head>";
    echo "<meta name='viewport' content='width=device-width, initial-scale=1' />";
    echo "<link rel='stylesheet' href='https://example.com/css/style.css'>";
    echo "<link rel='icon' type='image/png' href='https://example.com/favicon.png'>";
    echo "<title>Notice</title></head><body>";
    echo "<div class='invite-container'><h2>Notice</h2><p>$message</p></div>";
    echo "</body></html>";
    exit;
}

// Token can arrive via the emailed link (GET) or the form resubmit (POST).
$token = $_GET['token'] ?? $_POST['token'] ?? '';
if (!preg_match('/^[a-f0-9]{64}$/', $token)) {
    stop("Invalid reset link.");
}

$tokenFile = "$resetDir/$token";
if (!file_exists($tokenFile)) {
    stop("This reset link has already been used or has expired. <a href='/forgot-password.php'>Request a new one</a>.");
}

$lines = file($tokenFile, FILE_IGNORE_NEW_LINES);
$email = $lines[0] ?? '';
$expires = (int)($lines[1] ?? 0);

if (time() > $expires) {
    unlink($tokenFile);
    stop("This reset link has expired. <a href='/forgot-password.php'>Request a new one</a>.");
}

$error = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $password = $_POST['password'] ?? '';
    $passwordConfirm = $_POST['password_confirm'] ?? '';

    if (strlen($password) < 4) {
        $error = "Password must be at least 4 characters.";
    } elseif ($password !== $passwordConfirm) {
        $error = "Passwords don't match.";
    } else {
        // 1. Generate Hash
        $salt = '$6$rounds=5000$'.bin2hex(random_bytes(8)).'$';
        $hash = "{SHA512-CRYPT}" . crypt($password, $salt);

        // 2. Update the mailbox via the root-owned script (see
        // mail-reset-password.sh / sudoers-mail-scripts).
        shell_exec("sudo /usr/local/bin/mail-reset-password.sh " . escapeshellarg($email) . " " . escapeshellarg($hash));

        // 3. Burn the token -- one reset per link.
        unlink($tokenFile);

        // 4. Success Page
        echo "<!DOCTYPE html><html lang='en'><head>";
        echo "<meta charset='UTF-8'>";
        echo "<meta name='viewport' content='width=device-width, initial-scale=1' />";
        echo "<link rel='icon' type='image/png' href='https://example.com/favicon.png'>";
        echo "<title>Password reset</title>";
        echo "<link rel='stylesheet' href='https://example.com/css/style.css'>";
        echo "</head><body>";
        echo "<div class='invite-container'>";
        echo "<h2>Password updated</h2>";
        echo "<p>The password for <strong>" . htmlspecialchars($email) . "</strong> has been reset.</p>";
        echo "<p>You can log in with your new password now.</p>";
        echo "</div></body></html>";
        exit;
    }
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Mail — reset password</title>
<link rel="icon" type="image/png" href="https://example.com/favicon.png">
<link rel="stylesheet" href="https://example.com/css/style.css">
</head>
<body>
<div class="invite-container">
    <h2>Choose a new password</h2>
    <p>Resetting the password for <strong><?=htmlspecialchars($email)?></strong>.</p>

    <?php if ($error): ?>
    <p style="color:#c00;"><?=htmlspecialchars($error)?></p>
    <?php endif; ?>

    <form method="post">
        <input type="hidden" name="token" value="<?=htmlspecialchars($token)?>">

        <label for="password">New password (at least 4 characters):</label><br>
        <input type="password" name="password" id="password" required minlength="4"><br><br>

        <label for="password_confirm">Confirm new password:</label><br>
        <input type="password" name="password_confirm" id="password_confirm" required minlength="4"><br><br>

        <button type="submit">Reset password</button>
    </form>
</div>
</body>
</html>
