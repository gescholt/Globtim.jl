#!/bin/bash
# Fix GPG key email for GitLab verification

echo "=== Fix GPG Email for GitLab ==="
echo

KEY_ID="D8D30229B76968AE"
GITLAB_EMAIL="scholten@mpi-cbg.de"

echo "Current GPG key UIDs:"
gpg --list-keys $KEY_ID | grep uid
echo

# Check if the GitLab email is already in the key
if gpg --list-keys $KEY_ID | grep -q "$GITLAB_EMAIL"; then
    echo "✅ Email $GITLAB_EMAIL is already in your GPG key!"
    echo
    echo "Exporting updated public key for GitLab..."
    echo
else
    echo "❌ Email $GITLAB_EMAIL is NOT in your GPG key yet."
    echo
    echo "To add it, you need to run these commands:"
    echo
    echo "1. gpg --edit-key $KEY_ID"
    echo "2. Type: adduid"
    echo "3. Real name: Georgy Scholt"
    echo "4. Email address: $GITLAB_EMAIL"
    echo "5. Comment: (just press Enter)"
    echo "6. Change (N)ame, (C)omment, (E)mail or (O)kay/(Q)uit? O"
    echo "7. Enter your GPG passphrase"
    echo "8. Type: save"
    echo
    echo "After adding the email, run this script again to get the updated key."
    exit 0
fi

echo "Here's your updated public key with both emails:"
echo "Copy everything between the markers and update it on GitLab:"
echo
echo "========== START COPYING HERE =========="
gpg --armor --export $KEY_ID
echo "========== STOP COPYING HERE =========="
echo
echo "To update on GitLab:"
echo "1. Go to https://gitlab.com/-/profile/gpg_keys"
echo "2. Delete the old key (click the trash icon)"
echo "3. Click 'Add new GPG key'"
echo "4. Paste the new key above"
echo "5. Click 'Add key'"
echo
echo "The email $GITLAB_EMAIL should now show as verified!"