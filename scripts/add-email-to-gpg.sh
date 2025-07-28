#!/bin/bash
# Add email to existing GPG key

echo "=== Adding Email to GPG Key ==="
echo

KEY_ID="D8D30229B76968AE"
NEW_EMAIL="scholten@mpi-cbg.de"

echo "This will add $NEW_EMAIL to your GPG key $KEY_ID"
echo
echo "Steps:"
echo "1. Run: gpg --edit-key $KEY_ID"
echo "2. Type: adduid"
echo "3. Enter your name: Georgy Scholt"
echo "4. Enter email: $NEW_EMAIL"
echo "5. Enter comment (optional, just press Enter)"
echo "6. Confirm with 'O' (for Okay)"
echo "7. Enter your passphrase"
echo "8. Type: save"
echo
echo "After adding the email, run this script again to export the updated key."
echo
echo "Press Enter to continue or Ctrl+C to cancel..."
read

# Check if the email is already added
if gpg --list-keys $KEY_ID | grep -q "$NEW_EMAIL"; then
    echo "✅ Email $NEW_EMAIL is already added to the key!"
    echo
    echo "Here's your public key for GitLab:"
    echo
    echo "========== COPY EVERYTHING BELOW THIS LINE =========="
    gpg --armor --export $KEY_ID
    echo "========== COPY EVERYTHING ABOVE THIS LINE =========="
    echo
    echo "Paste this key at: https://gitlab.com/-/profile/gpg_keys"
else
    echo "Starting GPG key editor..."
    gpg --edit-key $KEY_ID
fi