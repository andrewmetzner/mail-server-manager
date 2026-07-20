# Example /etc/dovecot/sieve/default.sieve

require ["fileinto"];

if header :contains "X-Spam-Flag" "YES" {
    fileinto "Junk";
    stop;
}

if header :contains "Chat-Version" "1.0" {
    fileinto "DeltaChat";
    stop;
}
