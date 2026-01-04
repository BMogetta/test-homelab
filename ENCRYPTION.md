# Encrypted Environment Variables

This repository uses `age` encryption to safely store environment variables in version control.

## 🔐 Why Encrypt .env?

Your `.env` file contains sensitive information:
- Database passwords
- Admin credentials
- API keys

Instead of keeping these only on your local machine, you can:
- ✅ Store encrypted `.env.age` in the repository
- ✅ Clone on a new machine and decrypt
- ✅ Have a backup in case of disaster
- ✅ Maintain a single source of truth

## 📋 Quick Reference

### First Time Setup (Encrypting)

After you've configured your homelab with real passwords:

```bash
# 1. Make sure age is installed (already done by setup.sh)
which age

# 2. Encrypt your .env
./scripts/encrypt-env.sh

# 3. Commit the encrypted file
git add homelab/.env.age
git commit -m "Add encrypted environment variables"
git push
```

**Important:** Remember your encryption passphrase! Write it down somewhere safe.

### Fresh Installation (Decrypting)

When setting up on a new machine:

```bash
# 1. Clone and run setup
git clone https://github.com/YOUR_USERNAME/homelab-setup.git
cd homelab-setup
./setup.sh

# 2. The setup script will detect .env.age and offer to decrypt
# OR manually run:
./scripts/decrypt-env.sh

# 3. Start services
cd ~/homelab
podman-compose up -d
```

## 📝 Manual Usage

### Encrypt

```bash
./scripts/encrypt-env.sh
```

This will:
- Check that `~/homelab/.env` exists
- Prompt for a passphrase (choose a strong one!)
- Create `~/homelab/.env.age` (encrypted)
- Tell you how to commit it

### Decrypt

```bash
./scripts/decrypt-env.sh
```

This will:
- Check that `~/homelab/.env.age` exists
- Prompt for your passphrase
- Create `~/homelab/.env` (decrypted)
- Ready to use with podman-compose

## 🔄 Updating Credentials

When you change passwords in your `.env`:

```bash
# 1. Edit your .env
nano ~/homelab/.env

# 2. Re-encrypt
./scripts/encrypt-env.sh

# 3. Commit the updated encrypted file
git add homelab/.env.age
git commit -m "Update credentials"
git push
```

## 💾 Disaster Recovery

### Physical Backup

Create a physical backup document:

```bash
cat > ~/disaster-recovery-backup.txt << EOF
===========================================
HOMELAB DISASTER RECOVERY
===========================================
Date: $(date)

ENCRYPTION PASSPHRASE:
[WRITE YOUR PASSPHRASE HERE BY HAND]

REPOSITORY:
https://github.com/YOUR_USERNAME/homelab-setup.git

RECOVERY STEPS:
1. Fresh install Debian 12
2. git clone [repository above]
3. cd homelab-setup
4. ./setup.sh
5. When prompted, decrypt with passphrase above
6. cd ~/homelab && podman-compose up -d

IMPORTANT NOTES:
- Pi-hole password is in .env: PIHOLE_WEBPASSWORD
- MongoDB password is in .env: MONGO_PASS
- Change Nginx Proxy Manager default: admin@example.com

===========================================
EOF

# Print this and store it somewhere safe
cat ~/disaster-recovery-backup.txt
```

Print this document and store it in a safe place (fireproof safe, safety deposit box, etc.)

### Digital Backup

You can also:
1. Keep `disaster-recovery-backup.txt` on a USB drive
2. Store in a password manager (1Password, Bitwarden)
3. Email to yourself (encrypted)

## 🔒 Security Best Practices

### DO ✅
- Use a strong, unique passphrase for encryption
- Store your passphrase in a password manager
- Keep a physical backup of your passphrase
- Re-encrypt after changing credentials
- Review `.gitignore` ensures `.env` is never committed

### DON'T ❌
- Don't use a weak passphrase (no "password123")
- Don't store passphrase in the repository
- Don't commit unencrypted `.env` file
- Don't share encrypted file without sharing passphrase securely
- Don't lose your passphrase (no recovery possible)

## 🛠 Technical Details

### What is `age`?

`age` is a simple, modern file encryption tool:
- Easy to use (no GPG complexity)
- Secure (ChaCha20-Poly1305 encryption)
- Small (single binary)
- Fast
- Actively maintained

### File Locations

```
homelab-setup/
├── .env.example          # Template (committed to git)
├── scripts/
│   ├── encrypt-env.sh    # Encryption script
│   └── decrypt-env.sh    # Decryption script
└── homelab/
    ├── .env              # Actual credentials (NOT in git)
    └── .env.age          # Encrypted (committed to git)
```

### .gitignore Rules

```gitignore
*.env        # Block all .env files
!*.env.age   # EXCEPT .env.age (encrypted)
```

## ❓ FAQ

**Q: What if I forget my passphrase?**
A: There is no recovery. This is why physical backup is important.

**Q: Can I change my passphrase?**
A: Yes, just re-run `./scripts/encrypt-env.sh` with a new passphrase.

**Q: Is it safe to put .env.age on GitHub?**
A: Yes, as long as your passphrase is strong and not in the repository.

**Q: What if someone gets my .env.age file?**
A: Without the passphrase, they cannot decrypt it (assuming strong passphrase).

**Q: Can I use this for team projects?**
A: For personal projects: yes. For teams: consider a proper secrets manager (1Password, HashiCorp Vault, AWS Secrets Manager).

**Q: Do I need this for Raspberry Pi?**
A: No, but it makes fresh installs easier. You clone the repo and decrypt instead of manually setting up credentials again.

## 🔗 Related

- [age documentation](https://age-encryption.org/)
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
- [README.md](./README.md)
