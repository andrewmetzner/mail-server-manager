<?php
$inviteDir = '/var/lib/mail-invites';
$usersFile = '/etc/dovecot/users';
$domain = 'example.com';

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

// Get token from URL
$token = $_GET['token'] ?? '';
if (!preg_match('/^[a-f0-9]{64}$/', $token)) {
    stop("Invalid invite link.");
}

// Check if invite exists
$inviteFile = "$inviteDir/$token";
if (!file_exists($inviteFile)) {
    stop("This invite has already been used or expired.");
}

// The name given at invite-creation time (invite-user.sh <name> ...) is only
// used as a prefill suggestion -- the invitee picks the actual username below.
$suggestedUser = explode('@', trim(file_get_contents($inviteFile)))[0];

$error = '';
$postedUsername = '';
$postedRecovery = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $postedUsername = strtolower(trim($_POST['username'] ?? ''));
    $password = $_POST['password'] ?? '';
    $passwordConfirm = $_POST['password_confirm'] ?? '';
    $postedRecovery = trim($_POST['recovery_email'] ?? '');

    if (!preg_match('/^[a-z0-9._-]{1,64}$/', $postedUsername)) {
        $error = "Username can only contain lowercase letters, numbers, dots, dashes, and underscores.";
    } elseif (strlen($password) < 4) {
        $error = "Password must be at least 4 characters.";
    } elseif ($password !== $passwordConfirm) {
        $error = "Passwords don't match.";
    } elseif (!filter_var($postedRecovery, FILTER_VALIDATE_EMAIL)) {
        $error = "Please enter a valid recovery email.";
    } else {
        $email = "$postedUsername@$domain";

        // Availability check. www-data has a read ACL on $usersFile for
        // exactly this (see README.org).
        $existingUsers = @file_get_contents($usersFile);
        $taken = $existingUsers !== false
            && preg_match('/^' . preg_quote($email, '/') . ':/m', $existingUsers);

        if ($taken) {
            $error = htmlspecialchars($email) . " is already taken. Please choose another.";
        } else {
            // 1. Generate Hash
            $salt = '$6$rounds=5000$'.bin2hex(random_bytes(8)).'$';
            $hash = "{SHA512-CRYPT}" . crypt($password, $salt);

            // 2. Create the Mailbox via the Bash script
            shell_exec("sudo /usr/local/bin/mail-add-user.sh " . escapeshellarg($email) . " " . escapeshellarg($hash));

            // 3. Record the recovery email (used by recover-mail-password.sh, admin-side only)
            $recoveryDir = '/var/lib/mail-recovery';
            if (is_dir($recoveryDir)) {
                $recoveryFile = "$recoveryDir/$email";
                file_put_contents($recoveryFile, $postedRecovery);
                chmod($recoveryFile, 0600);
            }

            // 4. Delete the invite token
            unlink($inviteFile);

            // 5. Success Page
            echo "<!DOCTYPE html><html lang='en'><head>";
            echo "<meta charset='UTF-8'>";
            echo "<meta name='viewport' content='width=device-width, initial-scale=1' />";
            echo "<link rel='icon' type='image/png' href='https://example.com/favicon.png'>";
            echo "<title>Success</title>";
            echo "<link rel='stylesheet' href='https://example.com/css/style.css'>";
            echo "</head><body>";
            echo "<div class='invite-container'>";
            echo "<h2>Success!</h2>";
            echo "<p>The mailbox for <strong>" . htmlspecialchars($email) . "</strong> has been created.</p>";
            echo "<p>You may now log in via your mail client.</p>";
            echo "<p>Forgot your password later? <a href='/forgot-password.php'>Reset it here</a>.</p>";
            echo "</div></body></html>";
            exit;
        }
    }
}
?>

<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>Mail invite</title>
<link rel="icon" type="image/png" href="https://example.com/favicon.png">
<link rel="stylesheet" href="https://example.com/css/style.css">
</head>
<body>
<div class="invite-container">
    <h2>You're invited</h2>

    <?php if ($error): ?>
    <p style="color:#c00;"><?=htmlspecialchars($error)?></p>
    <?php endif; ?>

    <form method="post">
        <label for="username">Pick your email address:</label><br>
        <input type="text" name="username" id="username"
               value="<?=htmlspecialchars($postedUsername ?: $suggestedUser)?>"
               pattern="[a-z0-9._-]{1,64}" maxlength="64" required
               title="lowercase letters, numbers, dots, dashes, underscores only">@<?=htmlspecialchars($domain)?><br><br>

        <label for="password">Choose a password (at least 4 characters):</label><br>
        <input type="password" name="password" id="password" required minlength="4"><br><br>

        <label for="password_confirm">Confirm password:</label><br>
        <input type="password" name="password_confirm" id="password_confirm" required minlength="4"><br><br>

        <label for="recovery_email">Recovery email (used if you ever get locked out):</label><br>
        <input type="email" name="recovery_email" id="recovery_email" required
               value="<?=htmlspecialchars($postedRecovery)?>"><br><br>

        <button type="submit">Create account</button>
    </form>
</div>
</body>
</html>
