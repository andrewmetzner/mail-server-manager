<?php
$usersFile = '/etc/dovecot/users';
$recoveryDir = '/var/lib/mail-recovery';
$resetDir = '/var/lib/mail-password-resets';
$domain = 'example.com';
$resetUrl = 'https://mail.example.com/reset-password.php';
$resetTtlMinutes = 60;

// Helper function for pretty errors (fatal -- for invalid input only)
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

$error = '';
$postedEmail = '';
$sent = false;

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $postedEmail = strtolower(trim($_POST['email'] ?? ''));

    if (!filter_var($postedEmail, FILTER_VALIDATE_EMAIL)) {
        $error = "Please enter a valid email address.";
    } else {
        // Only ever act on our own domain's mailboxes -- silently no-op
        // for anything else instead of erroring, so this can't be used to
        // probe whether an address belongs to this server or not.
        if (substr($postedEmail, -strlen("@$domain")) === "@$domain") {
            $existingUsers = @file_get_contents($usersFile);
            $accountExists = $existingUsers !== false
                && preg_match('/^' . preg_quote($postedEmail, '/') . ':/m', $existingUsers);

            $recoveryFile = "$recoveryDir/$postedEmail";

            if ($accountExists && is_dir($resetDir) && file_exists($recoveryFile)) {
                $recoveryEmail = trim(file_get_contents($recoveryFile));

                // Invalidate any previous outstanding tokens for this
                // mailbox so old links stop working once a new one is sent.
                foreach ((glob("$resetDir/*") ?: []) as $f) {
                    $lines = @file($f, FILE_IGNORE_NEW_LINES);
                    if ($lines && ($lines[0] ?? '') === $postedEmail) {
                        @unlink($f);
                    }
                }

                $token = bin2hex(random_bytes(32));
                $expires = time() + $resetTtlMinutes * 60;
                $tokenFile = "$resetDir/$token";
                file_put_contents($tokenFile, "$postedEmail\n$expires\n");
                chmod($tokenFile, 0600);

                $link = "$resetUrl?token=$token";
                $body = "A password reset was requested for $postedEmail.\n\n"
                    . "Click the link below to choose a new password (valid for $resetTtlMinutes minutes):\n\n"
                    . "$link\n\n"
                    . "If you didn't request this, you can ignore this email -- nothing changes until the link above is used.\n";

                $mailCmd = "mail -s " . escapeshellarg("Password reset for $postedEmail")
                    . " -a " . escapeshellarg("From: Mail Admin <postmaster@$domain>")
                    . " " . escapeshellarg($recoveryEmail);

                $proc = proc_open($mailCmd, [0 => ['pipe', 'r'], 1 => ['pipe', 'w'], 2 => ['pipe', 'w']], $pipes);
                if (is_resource($proc)) {
                    fwrite($pipes[0], $body);
                    fclose($pipes[0]);
                    fclose($pipes[1]);
                    fclose($pipes[2]);
                    proc_close($proc);
                }
            }
        }

        // Same message either way -- don't reveal whether the address
        // exists, has a recovery email on file, or belongs to this domain.
        $sent = true;
    }
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Mail — forgot password</title>
<link rel="icon" type="image/png" href="https://example.com/favicon.png">
<link rel="stylesheet" href="https://example.com/css/style.css">
</head>
<body>
<div class="invite-container">
    <h2>Forgot your password?</h2>

    <?php if ($sent): ?>
    <p>If <strong><?=htmlspecialchars($postedEmail)?></strong> exists and has a
       recovery email on file, a reset link was just sent to it. The link
       expires in <?=$resetTtlMinutes?> minutes.</p>
    <p><small>Accounts created before the recovery-email feature was added
       won't have one on file -- contact an admin directly in that case.</small></p>
    <?php else: ?>
    <?php if ($error): ?>
    <p style="color:#c00;"><?=htmlspecialchars($error)?></p>
    <?php endif; ?>
    <p>Enter your mailbox address and we'll email a reset link to the
       recovery address you gave at signup.</p>
    <form method="post">
        <label for="email">Your mailbox address:</label><br>
        <input type="email" name="email" id="email" required maxlength="255"
               value="<?=htmlspecialchars($postedEmail)?>"
               placeholder="you@<?=htmlspecialchars($domain)?>"><br><br>
        <button type="submit">Send reset link</button>
    </form>
    <?php endif; ?>
</div>
</body>
</html>
